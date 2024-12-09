// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

import {WadRayMath} from '../libraries/math/WadRayMath.sol';
import {PercentageMath} from '../libraries/math/PercentageMath.sol';
import {InputTypes} from '../libraries/types/InputTypes.sol';
import {Errors} from '../libraries/helpers/Errors.sol';

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';
import {IACLManager} from 'src/interfaces/IACLManager.sol';
import {IInterestRateModel} from '../interfaces/IInterestRateModel.sol';
import {IDefaultInterestRateModel} from '../interfaces/IDefaultInterestRateModel.sol';

/**
 * @title DefaultInterestRateModel contract
 * @notice Implements the calculation of the interest rates depending on the reserve state
 * @dev The model of interest rate is based on 2 slopes, one before the `OPTIMAL_USAGE_RATIO`
 * point of usage and another from that one to 100%.
 */
contract DefaultInterestRateModel is IDefaultInterestRateModel, Initializable {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  event InterestRateParamsUpdate(
    uint32 indexed poolId,
    address indexed reserve,
    uint256 group,
    uint256 optimalUtilizationRate,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  struct InterestRateParams {
    // Utilization rate at which the pool aims to obtain most competitive borrow rates. Expressed in ray.
    uint256 optimalUtilizationRate;
    // Base variable borrow rate when Utilization rate = 0. Expressed in ray
    uint256 baseVariableBorrowRate;
    // Slope of the variable interest curve when utilization rate > 0 and <= optimalUtilizationRate. Expressed in ray
    uint256 variableRateSlope1;
    // Slope of the variable interest curve when utilization rate > optimalUtilizationRate. Expressed in ray
    uint256 variableRateSlope2;
  }

  uint256 public constant MAX_BORROW_RATE = 1000e25; // 1000%
  uint256 public constant MIN_OPTIMAL_RATE = 1e25; // 1%
  uint256 public constant MAX_OPTIMAL_RATE = 99e25; // 99%

  IAddressProvider public addressProvider;
  // pool => (asset => (group => params))
  mapping(uint32 => mapping(address => mapping(uint256 => InterestRateParams))) internal _interestRateParams;

  // Modifiers
  modifier onlyPoolAdmin() {
    __onlyPoolAdmin();
    _;
  }

  function __onlyPoolAdmin() internal view {
    require(IACLManager(addressProvider.getACLManager()).isPoolAdmin(msg.sender), Errors.CALLER_NOT_POOL_ADMIN);
  }

  /**
   * @dev Constructor.
   */
  constructor() {
    _disableInitializers();
  }

  function initialize(address provider) public initializer {
    addressProvider = IAddressProvider(provider);
  }

  function setInterestRateParams(
    uint32 pool,
    address asset,
    uint256 group,
    uint256 optimalRate,
    uint256 baseRate,
    uint256 slope1,
    uint256 slope2
  ) public onlyPoolAdmin {
    _setInterestRateParams(
      pool,
      asset,
      group,
      InterestRateParams({
        optimalUtilizationRate: optimalRate,
        baseVariableBorrowRate: baseRate,
        variableRateSlope1: slope1,
        variableRateSlope2: slope2
      })
    );
  }

  function setInterestRateParams(
    uint32 pool,
    address asset,
    uint256 group,
    bytes calldata rateData
  ) public onlyPoolAdmin {
    _setInterestRateParams(pool, asset, group, abi.decode(rateData, (InterestRateParams)));
  }

  function setInterestRateParams(
    uint32 pool,
    address asset,
    uint256 group,
    InterestRateParams calldata rateData
  ) public onlyPoolAdmin {
    _setInterestRateParams(pool, asset, group, rateData);
  }

  function getInterestRateParams(
    uint32 pool,
    address asset,
    uint256 group
  ) public view returns (InterestRateParams memory) {
    return _interestRateParams[pool][asset][group];
  }

  function getOptimalUtilizationRate(uint32 pool, address asset, uint256 group) public view override returns (uint256) {
    return _interestRateParams[pool][asset][group].optimalUtilizationRate;
  }

  function getBaseVariableBorrowRate(uint32 pool, address asset, uint256 group) public view override returns (uint256) {
    return _interestRateParams[pool][asset][group].baseVariableBorrowRate;
  }

  function getVariableRateSlope1(uint32 pool, address asset, uint256 group) public view override returns (uint256) {
    return _interestRateParams[pool][asset][group].variableRateSlope1;
  }

  function getVariableRateSlope2(uint32 pool, address asset, uint256 group) public view override returns (uint256) {
    return _interestRateParams[pool][asset][group].variableRateSlope2;
  }

  function getMaxVariableBorrowRate(uint32 pool, address asset, uint256 group) public view override returns (uint256) {
    InterestRateParams memory rateParams = _interestRateParams[pool][asset][group];

    return rateParams.baseVariableBorrowRate + (rateParams.variableRateSlope1) + (rateParams.variableRateSlope2);
  }

  struct CalcInterestRatesLocalVars {
    uint256 currentBorrowRate;
    uint256 excessUtilizationRate;
    uint256 excessBorrowRate;
  }

  /// @inheritdoc IInterestRateModel
  function calculateGroupBorrowRate(
    uint32 pool,
    address asset,
    uint256 group,
    uint256 utilizationRate
  ) public view override returns (uint256) {
    InterestRateParams memory rateParams = _interestRateParams[pool][asset][group];
    require(rateParams.optimalUtilizationRate > 0, Errors.INVALID_OPTIMAL_USAGE_RATIO);

    CalcInterestRatesLocalVars memory vars;
    vars.currentBorrowRate = rateParams.baseVariableBorrowRate;

    if (utilizationRate > rateParams.optimalUtilizationRate) {
      vars.excessUtilizationRate = WadRayMath.RAY - (rateParams.optimalUtilizationRate);
      vars.excessBorrowRate = (utilizationRate - rateParams.optimalUtilizationRate).rayDiv(vars.excessUtilizationRate);

      vars.currentBorrowRate +=
        rateParams.variableRateSlope1 +
        rateParams.variableRateSlope2.rayMul(vars.excessBorrowRate);
    } else {
      vars.currentBorrowRate += rateParams.variableRateSlope1.rayMul(utilizationRate).rayDiv(
        rateParams.optimalUtilizationRate
      );
    }

    return (vars.currentBorrowRate);
  }

  /**
   * @dev Doing validations and params update for an asset
   * @param asset address of the underlying asset
   * @param rateParams Encoded interest rate params to apply
   */
  function _setInterestRateParams(
    uint32 pool,
    address asset,
    uint256 group,
    InterestRateParams memory rateParams
  ) internal {
    require(asset != address(0), Errors.INVALID_ADDRESS);

    require(
      rateParams.optimalUtilizationRate <= MAX_OPTIMAL_RATE && rateParams.optimalUtilizationRate >= MIN_OPTIMAL_RATE,
      Errors.INVALID_OPTIMAL_USAGE_RATIO
    );

    require(rateParams.variableRateSlope1 <= rateParams.variableRateSlope2, Errors.SLOPE_2_MUST_BE_GTE_SLOPE_1);

    // The maximum rate should not be above certain threshold
    uint256 maxBorrowRate = rateParams.baseVariableBorrowRate +
      (rateParams.variableRateSlope1) +
      (rateParams.variableRateSlope2);
    require(maxBorrowRate <= MAX_BORROW_RATE, Errors.INVALID_MAX_RATE);

    _interestRateParams[pool][asset][group] = rateParams;

    emit InterestRateParamsUpdate(
      pool,
      asset,
      group,
      rateParams.optimalUtilizationRate,
      rateParams.baseVariableBorrowRate,
      rateParams.variableRateSlope1,
      rateParams.variableRateSlope2
    );
  }
}
