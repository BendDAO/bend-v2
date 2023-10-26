// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IPriceOracleGetter} from '../../interfaces/IPriceOracleGetter.sol';

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';
import {GenericLogic} from './GenericLogic.sol';

library LiquidationLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // See `IPool` for descriptions
  event LiquidateERC20(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool supplyAsCollateral
  );

  /**
   * @dev Default percentage of borrower's debt to be repaid in a liquidation.
   * @dev Percentage applied when the users health factor is above `CLOSE_FACTOR_HF_THRESHOLD`
   * Expressed in bps, a value of 0.5e4 results in 50.00%
   */
  uint256 internal constant DEFAULT_LIQUIDATION_CLOSE_FACTOR = 0.5e4;

  /**
   * @dev Maximum percentage of borrower's debt to be repaid in a liquidation
   * @dev Percentage applied when the users health factor is below `CLOSE_FACTOR_HF_THRESHOLD`
   * Expressed in bps, a value of 1e4 results in 100.00%
   */
  uint256 public constant MAX_LIQUIDATION_CLOSE_FACTOR = 1e4;

  /**
   * @dev This constant represents below which health factor value it is possible to liquidate
   * an amount of debt corresponding to `MAX_LIQUIDATION_CLOSE_FACTOR`.
   * A value of 0.95e18 results in 0.95
   */
  uint256 public constant CLOSE_FACTOR_HF_THRESHOLD = 0.95e18;

  struct LiquidateERC20LocalVars {
    uint256 userCollateralBalance;
    uint256 userTotalDebt;
    uint256 actualDebtToLiquidate;
    uint256 actualCollateralToLiquidate;
    uint256 healthFactor;
  }

  /**
   * @notice Function to liquidate a position if its Health Factor drops below 1. The caller (liquidator)
   * covers `debtToCover` amount of debt of the user getting liquidated, and receives
   * a proportional amount of the `collateralAsset` plus a bonus to cover market risk
   */
  function executeLiquidateERC20(InputTypes.ExecuteLiquidateERC20Params memory params) external {
    LiquidateERC20LocalVars memory vars;

    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage collateralAssetData = poolData.assetLookup[params.collateralAsset];
    DataTypes.GroupData storage collateralGroupData = poolData.groupLookup[collateralAssetData.groupId];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[params.debtAsset];
    DataTypes.GroupData storage debtGroupData = poolData.groupLookup[debtAssetData.groupId];

    InterestLogic.updateInterestIndexs(debtAssetData, debtGroupData);

    (, , , , vars.healthFactor, ) = GenericLogic.calculateUserAccountData(poolData, params.user, cs.priceOracle);

    require(
      vars.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.LE_HEALTH_FACTOR_NOT_BELOW_THRESHOLD
    );

    (vars.userTotalDebt, vars.actualDebtToLiquidate) = _calculateUserDebt(
      debtAssetData,
      debtGroupData,
      params,
      vars.healthFactor
    );

    vars.userCollateralBalance = VaultLogic.erc20GetUserSupply(collateralAssetData, params.user);

    (vars.actualCollateralToLiquidate, vars.actualDebtToLiquidate) = _calculateAvailableCollateralToLiquidate(
      collateralAssetData,
      debtAssetData,
      params.collateralAsset,
      params.debtAsset,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      uint256(collateralAssetData.liquidationBonus),
      IPriceOracleGetter(cs.priceOracle)
    );

    // If the debt being repaid is equal to the user borrow,
    // we set the asset as not being used as collateral anymore
    if (vars.userTotalDebt == vars.actualDebtToLiquidate) {
      // TODO: accountRemoveAsset
    }

    // If the collateral being liquidated is equal to the user supply,
    // we set the asset as not being used as collateral anymore
    if (vars.actualCollateralToLiquidate == vars.userCollateralBalance) {
      // TODO: accountRemoveAsset
    }

    _repayUserDebt(debtAssetData, debtGroupData, params, vars);

    InterestLogic.updateInterestRates(
      poolData,
      params.debtAsset,
      debtAssetData,
      debtAssetData.groupId,
      debtGroupData,
      vars.actualDebtToLiquidate,
      0
    );

    if (params.supplyAsCollateral) {
      _supplyUserCollateralToLiquidator(collateralAssetData, params, vars);
    } else {
      _transferUserCollateralToLiquidator(poolData, collateralAssetData, collateralGroupData, params, vars);
    }

    // Transfers the debt asset being repaid to the vault, where the liquidity is kept
    VaultLogic.erc20TransferIn(params.debtAsset, msg.sender, vars.actualDebtToLiquidate);

    emit LiquidateERC20(
      params.collateralAsset,
      params.debtAsset,
      params.user,
      vars.actualDebtToLiquidate,
      vars.actualCollateralToLiquidate,
      msg.sender,
      params.supplyAsCollateral
    );
  }

  /**
   * @notice Burns the collateral tokens and transfers the underlying to the liquidator.
   * @dev   The function also updates the state and the interest rate of the collateral reserve.
   */
  function _transferUserCollateralToLiquidator(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage collateralAssetData,
    DataTypes.GroupData storage collateralGroupData,
    InputTypes.ExecuteLiquidateERC20Params memory params,
    LiquidateERC20LocalVars memory vars
  ) internal {
    InterestLogic.updateInterestIndexs(collateralAssetData, collateralGroupData);

    // Burn the equivalent amount of collateral, sending the underlying to the liquidator
    VaultLogic.erc20DecreaseSupply(collateralAssetData, params.user, vars.actualCollateralToLiquidate);

    VaultLogic.erc20TransferOut(params.collateralAsset, msg.sender, vars.actualCollateralToLiquidate);

    InterestLogic.updateInterestRates(
      poolData,
      params.collateralAsset,
      collateralAssetData,
      0,
      collateralGroupData,
      0,
      vars.actualCollateralToLiquidate
    );
  }

  /**
   * @notice Liquidates the user collateral by transferring them to the liquidator.
   * @dev   The function also checks the state of the liquidator and activates the aToken as collateral
   *        as in standard transfers if the isolation mode constraints are respected.
   */
  function _supplyUserCollateralToLiquidator(
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteLiquidateERC20Params memory params,
    LiquidateERC20LocalVars memory vars
  ) internal {
    uint256 liquidatorPreviousBalance = VaultLogic.erc20GetUserSupply(collateralAssetData, msg.sender);

    VaultLogic.erc20TransferSupply(collateralAssetData, params.user, msg.sender, vars.actualCollateralToLiquidate);

    if (liquidatorPreviousBalance == 0) {
      // TODO: VaultLogic.accountAddAsset();
    }
  }

  /**
   * @notice Burns the debt of the user up to the amount being repaid by the liquidator.
   * @dev The function alters the `debtReserveCache` state in `vars` to update the debt related data.
   * @param params The additional parameters needed to execute the liquidation function
   * @param vars the executeLiquidationCall() function local vars
   */
  function _repayUserDebt(
    DataTypes.AssetData storage debtAssetData,
    DataTypes.GroupData storage debtGroupData,
    InputTypes.ExecuteLiquidateERC20Params memory params,
    LiquidateERC20LocalVars memory vars
  ) internal {
    // TODO: burn group debt from highest interest rate to lowest
    VaultLogic.erc20DecreaseBorrow(debtGroupData, params.user, vars.actualDebtToLiquidate);
  }

  /**
   * @notice Calculates the total debt of the user and the actual amount to liquidate depending on the health factor
   * and corresponding close factor.
   * @dev If the Health Factor is below CLOSE_FACTOR_HF_THRESHOLD, the close factor is increased to MAX_LIQUIDATION_CLOSE_FACTOR
   * @return The total debt of the user
   * @return The actual debt to liquidate as a function of the closeFactor
   */
  function _calculateUserDebt(
    DataTypes.AssetData storage debtAssetData,
    DataTypes.GroupData storage debtGroupData,
    InputTypes.ExecuteLiquidateERC20Params memory params,
    uint256 healthFactor
  ) internal view returns (uint256, uint256) {
    uint256 userTotalDebt = VaultLogic.erc20GetUserBorrow(debtGroupData, params.user);

    uint256 closeFactor = healthFactor > CLOSE_FACTOR_HF_THRESHOLD
      ? DEFAULT_LIQUIDATION_CLOSE_FACTOR
      : MAX_LIQUIDATION_CLOSE_FACTOR;

    uint256 maxLiquidatableDebt = userTotalDebt.percentMul(closeFactor);

    uint256 actualDebtToLiquidate = params.debtToCover > maxLiquidatableDebt ? maxLiquidatableDebt : params.debtToCover;

    return (userTotalDebt, actualDebtToLiquidate);
  }

  struct AvailableCollateralToLiquidateLocalVars {
    uint256 collateralPrice;
    uint256 debtAssetPrice;
    uint256 maxCollateralToLiquidate;
    uint256 baseCollateral;
    uint256 bonusCollateral;
    uint256 debtAssetDecimals;
    uint256 collateralDecimals;
    uint256 collateralAssetUnit;
    uint256 debtAssetUnit;
    uint256 collateralAmount;
    uint256 debtAmountNeeded;
  }

  /**
   * @notice Calculates how much of a specific collateral can be liquidated, given
   * a certain amount of debt asset.
   * @dev This function needs to be called after all the checks to validate the liquidation have been performed,
   *   otherwise it might fail.
   * @return The maximum amount that is possible to liquidate given all the liquidation constraints (user balance, close factor)
   * @return The amount to repay with the liquidation
   */
  function _calculateAvailableCollateralToLiquidate(
    DataTypes.AssetData storage collateralAssetData,
    DataTypes.AssetData storage debtAssetData,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    uint256 userCollateralBalance,
    uint256 liquidationBonus,
    IPriceOracleGetter oracle
  ) internal view returns (uint256, uint256) {
    AvailableCollateralToLiquidateLocalVars memory vars;

    vars.collateralPrice = oracle.getAssetPrice(collateralAsset);
    vars.debtAssetPrice = oracle.getAssetPrice(debtAsset);

    vars.collateralDecimals = collateralAssetData.underlyingDecimals;
    vars.debtAssetDecimals = debtAssetData.underlyingDecimals;

    unchecked {
      vars.collateralAssetUnit = 10 ** vars.collateralDecimals;
      vars.debtAssetUnit = 10 ** vars.debtAssetDecimals;
    }

    // This is the base collateral to liquidate based on the given debt to cover
    vars.baseCollateral =
      ((vars.debtAssetPrice * debtToCover * vars.collateralAssetUnit)) /
      (vars.collateralPrice * vars.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(liquidationBonus);

    if (vars.maxCollateralToLiquidate > userCollateralBalance) {
      vars.collateralAmount = userCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralPrice * vars.collateralAmount * vars.debtAssetUnit) /
        (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(liquidationBonus);
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = debtToCover;
    }

    return (vars.collateralAmount, vars.debtAmountNeeded);
  }
}
