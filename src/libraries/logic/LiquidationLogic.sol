// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

import {IPriceOracleGetter} from '../../interfaces/IPriceOracleGetter.sol';

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {ResultTypes} from '../types/ResultTypes.sol';

import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {KVSortUtils} from '../helpers/KVSortUtils.sol';

import {StorageSlot} from './StorageSlot.sol';
import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';
import {GenericLogic} from './GenericLogic.sol';

library LiquidationLogic {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

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
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[params.debtAsset];
    DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[debtAssetData.riskGroupId];

    InterestLogic.updateInterestBorrowIndex(debtAssetData, debtGroupData);

    ResultTypes.UserAccountResult memory userAccountResult = GenericLogic.calculateUserAccountDataForLiquidate(
      poolData,
      address(0),
      params.user,
      cs.priceOracle
    );

    require(
      userAccountResult.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD
    );
    require(collateralAssetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.INVALID_ASSET_TYPE);

    (vars.userTotalDebt, vars.actualDebtToLiquidate) = _calculateUserERC20Debt(
      debtGroupData,
      params,
      userAccountResult.healthFactor
    );

    vars.userCollateralBalance = VaultLogic.erc20GetUserSupply(collateralAssetData, params.user);

    (vars.actualCollateralToLiquidate, vars.actualDebtToLiquidate) = _calculateAvailableERC20CollateralToLiquidate(
      collateralAssetData,
      debtAssetData,
      params.collateralAsset,
      params.debtAsset,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      IPriceOracleGetter(cs.priceOracle)
    );

    // Transfers the debt asset being repaid to the vault, where the liquidity is kept
    VaultLogic.erc20TransferIn(params.debtAsset, msg.sender, vars.actualDebtToLiquidate);

    // If the debt being repaid is equal to the user borrow,
    // we set the asset as not being used as collateral anymore
    if (vars.userTotalDebt == vars.actualDebtToLiquidate) {
      // TODO: accountSetBorrowedAsset(false)
    }

    _repayUserERC20Debt(debtAssetData, params.user, vars.actualDebtToLiquidate, true);

    InterestLogic.updateInterestRates(params.debtAsset, debtAssetData, vars.actualDebtToLiquidate, 0);

    // If the collateral being liquidated is equal to the user supply,
    // we set the asset as not being used as collateral anymore
    if (vars.actualCollateralToLiquidate == vars.userCollateralBalance) {
      // TODO: accountSetSuppliedAsset(false)
    }

    if (params.supplyAsCollateral) {
      _supplyUserERC20CollateralToLiquidator(collateralAssetData, params, vars);
    } else {
      _transferUserERC20CollateralToLiquidator(collateralAssetData, params, vars);
    }

    emit Events.LiquidateERC20(
      msg.sender,
      params.user,
      params.collateralAsset,
      params.debtAsset,
      vars.actualDebtToLiquidate,
      vars.actualCollateralToLiquidate,
      params.supplyAsCollateral
    );
  }

  struct LiquidateERC721LocalVars {
    uint256 userCollateralBalance;
    uint256 userTotalDebt;
    uint256 actualDebtToLiquidate;
    ResultTypes.UserAccountResult userAccountResult;
  }

  /**
   * @notice Function to liquidate a ERC721 collateral if its Health Factor drops below 1.
   */
  function executeLiquidateERC721(InputTypes.ExecuteLiquidateERC721Params memory params) external {
    LiquidateERC721LocalVars memory vars;

    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    params.debtAsset = cs.nativeWrappedToken;

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage collateralAssetData = poolData.assetLookup[params.collateralAsset];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[params.debtAsset];
    DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[debtAssetData.riskGroupId];

    InterestLogic.updateInterestBorrowIndex(debtAssetData, debtGroupData);

    vars.userAccountResult = GenericLogic.calculateUserAccountDataForLiquidate(
      poolData,
      params.collateralAsset,
      params.user,
      cs.priceOracle
    );

    require(
      vars.userAccountResult.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD
    );
    require(collateralAssetData.assetType == Constants.ASSET_TYPE_ERC721, Errors.INVALID_ASSET_TYPE);

    vars.userTotalDebt = VaultLogic.erc20GetUserBorrow(debtGroupData, params.user);

    vars.userCollateralBalance = VaultLogic.erc721GetUserCrossSupply(collateralAssetData, params.user);

    vars.actualDebtToLiquidate = _calculateDebtAmountFromERC721Collateral(
      collateralAssetData,
      debtAssetData,
      params,
      vars,
      IPriceOracleGetter(cs.priceOracle)
    );

    // Transfers the debt asset being repaid to the vault, where the liquidity is kept
    VaultLogic.erc20TransferIn(params.debtAsset, msg.sender, vars.actualDebtToLiquidate);

    // If the debt being repaid is equal to the user borrow,
    // we set the asset as not being used as collateral anymore
    if (vars.userTotalDebt == vars.actualDebtToLiquidate) {
      // TODO: accountSetBorrowedAsset(false)
    }

    _repayUserERC20Debt(debtAssetData, params.user, vars.actualDebtToLiquidate, false);

    InterestLogic.updateInterestRates(params.debtAsset, debtAssetData, vars.actualDebtToLiquidate, 0);

    if (params.supplyAsCollateral) {
      _supplyUserERC721CollateralToLiquidator(collateralAssetData, params);
    } else {
      _transferUserERC721CollateralToLiquidator(collateralAssetData, params);
    }

    // If the collateral being liquidated is equal to the user supply,
    // we set the asset as not being used as collateral anymore
    if (params.collateralTokenIds.length == vars.userCollateralBalance) {
      // TODO: accountSetSuppliedAsset(false)
    }

    emit Events.LiquidateERC721(
      msg.sender,
      params.user,
      params.collateralAsset,
      params.collateralTokenIds,
      params.supplyAsCollateral
    );
  }

  /**
   * @notice Transfers the underlying ERC20 to the liquidator.
   */
  function _transferUserERC20CollateralToLiquidator(
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteLiquidateERC20Params memory params,
    LiquidateERC20LocalVars memory vars
  ) internal {
    InterestLogic.updateInterestSupplyIndex(collateralAssetData);

    // Burn the equivalent amount of collateral, sending the underlying to the liquidator
    VaultLogic.erc20DecreaseSupply(collateralAssetData, params.user, vars.actualCollateralToLiquidate);

    VaultLogic.erc20TransferOut(params.collateralAsset, msg.sender, vars.actualCollateralToLiquidate);

    InterestLogic.updateInterestRates(params.collateralAsset, collateralAssetData, 0, vars.actualCollateralToLiquidate);
  }

  /**
   * @notice Liquidates the user erc20 collateral by transferring them to the liquidator.
   */
  function _supplyUserERC20CollateralToLiquidator(
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteLiquidateERC20Params memory params,
    LiquidateERC20LocalVars memory vars
  ) internal {
    uint256 liquidatorPreviousBalance = VaultLogic.erc20GetUserSupply(collateralAssetData, msg.sender);

    VaultLogic.erc20TransferSupply(collateralAssetData, params.user, msg.sender, vars.actualCollateralToLiquidate);

    if (liquidatorPreviousBalance == 0) {
      // TODO: VaultLogic.accountSetSuppliedAsset();
    }
  }

  /**
   * @notice Burns the debt of the user up to the amount being repaid by the liquidator.
   */
  function _repayUserERC20Debt(
    DataTypes.AssetData storage debtAssetData,
    address user,
    uint256 actualDebtToLiquidate,
    bool checkRemainDebtZero
  ) internal {
    // sort group debt from highest interest rate to lowest
    uint256[] memory assetGroupIds = debtAssetData.groupList.values();
    KVSortUtils.KeyValue[] memory groupRateList = new KVSortUtils.KeyValue[](assetGroupIds.length);
    for (uint256 i = 0; i < groupRateList.length; i++) {
      groupRateList[i].key = assetGroupIds[i];
      DataTypes.GroupData storage loopGroupData = debtAssetData.groupLookup[uint8(groupRateList[i].key)];
      groupRateList[i].val = loopGroupData.borrowRate;
    }
    KVSortUtils.sort(groupRateList);

    // repay group debt one by one
    uint256 remainDebtToLiquidate = actualDebtToLiquidate;
    for (uint256 i = 0; i < groupRateList.length; i++) {
      DataTypes.GroupData storage loopGroupData = debtAssetData.groupLookup[uint8(groupRateList[i].key)];
      uint256 curDebtRepayAmount = VaultLogic.erc20GetUserBorrow(loopGroupData, user);
      if (curDebtRepayAmount > remainDebtToLiquidate) {
        curDebtRepayAmount = remainDebtToLiquidate;
        remainDebtToLiquidate = 0;
      } else {
        remainDebtToLiquidate -= curDebtRepayAmount;
      }
      VaultLogic.erc20DecreaseBorrow(loopGroupData, user, curDebtRepayAmount);
    }

    require(!checkRemainDebtZero || (remainDebtToLiquidate == 0), '');
  }

  /**
   * @notice Calculates the total debt of the user and the actual amount to liquidate depending on the health factor
   * and corresponding close factor.
   * @dev If the Health Factor is below CLOSE_FACTOR_HF_THRESHOLD, the close factor is increased to MAX_LIQUIDATION_CLOSE_FACTOR
   * @return The total debt of the user
   * @return The actual debt to liquidate as a function of the closeFactor
   */
  function _calculateUserERC20Debt(
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

  struct AvailableERC20CollateralToLiquidateLocalVars {
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
   * @notice Calculates how much of a specific collateral can be liquidated, given a certain amount of debt asset.
   */
  function _calculateAvailableERC20CollateralToLiquidate(
    DataTypes.AssetData storage collateralAssetData,
    DataTypes.AssetData storage debtAssetData,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    uint256 userCollateralBalance,
    IPriceOracleGetter oracle
  ) internal view returns (uint256, uint256) {
    AvailableERC20CollateralToLiquidateLocalVars memory vars;

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

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(
      PercentageMath.PERCENTAGE_FACTOR + collateralAssetData.liquidationBonus
    );

    if (vars.maxCollateralToLiquidate > userCollateralBalance) {
      vars.collateralAmount = userCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralPrice * vars.collateralAmount * vars.debtAssetUnit) /
        (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(
          PercentageMath.PERCENTAGE_FACTOR + collateralAssetData.liquidationBonus
        );
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = debtToCover;
    }

    return (vars.collateralAmount, vars.debtAmountNeeded);
  }

  /**
   * @notice Transfers the underlying ERC721 to the liquidator.
   */
  function _transferUserERC721CollateralToLiquidator(
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteLiquidateERC721Params memory params
  ) internal {
    // Burn the equivalent amount of collateral, sending the underlying to the liquidator
    VaultLogic.erc721DecreaseSupply(collateralAssetData, params.user, params.collateralTokenIds);

    VaultLogic.erc721TransferOut(params.collateralAsset, msg.sender, params.collateralTokenIds);
  }

  /**
   * @notice Liquidates the user erc721 collateral by transferring them to the liquidator.
   */
  function _supplyUserERC721CollateralToLiquidator(
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteLiquidateERC721Params memory params
  ) internal {
    uint256 liquidatorPreviousBalance = VaultLogic.erc721GetUserCrossSupply(collateralAssetData, msg.sender);

    VaultLogic.erc721TransferSupply(collateralAssetData, params.user, msg.sender, params.collateralTokenIds);

    if (liquidatorPreviousBalance == 0) {
      // TODO: VaultLogic.accountSetSuppliedAsset();
    }
  }

  struct CalculateDebtAmountFromERC721CollateralLocalVars {
    uint256 collateralPrice;
    uint256 collateralBonusPrice;
    uint256 collateralLiquidatePrice;
    uint256 collateralTotalDebtToCover;
    uint256 collateralItemDebtToCover;
    uint256 debtAssetPrice;
    uint256 collateralAssetUnit;
    uint256 debtAssetDecimals;
    uint256 debtAssetUnit;
    uint256 debtAmountNeeded;
  }

  /**
   * @notice Calculates how much of a specific debt can be covered, given a certain amount of collateral asset.
   */
  function _calculateDebtAmountFromERC721Collateral(
    DataTypes.AssetData storage collateralAssetData,
    DataTypes.AssetData storage debtAssetData,
    InputTypes.ExecuteLiquidateERC721Params memory params,
    LiquidateERC721LocalVars memory liqVars,
    IPriceOracleGetter oracle
  ) internal view returns (uint256) {
    CalculateDebtAmountFromERC721CollateralLocalVars memory vars;

    vars.collateralAssetUnit = oracle.BASE_CURRENCY_UNIT();
    vars.collateralPrice = oracle.getAssetPrice(params.collateralAsset);
    vars.collateralBonusPrice = vars.collateralPrice.percentMul(
      PercentageMath.PERCENTAGE_FACTOR - collateralAssetData.liquidationBonus
    );

    vars.debtAssetDecimals = debtAssetData.underlyingDecimals;
    vars.debtAssetUnit = 10 ** vars.debtAssetDecimals;
    vars.debtAssetPrice = oracle.getAssetPrice(params.debtAsset);

    // calculate the debt should be covered by the liquidated collateral of user
    vars.collateralTotalDebtToCover =
      (liqVars.userAccountResult.inputCollateralInBaseCurrency * liqVars.userAccountResult.totalDebtInBaseCurrency) /
      liqVars.userAccountResult.totalCollateralInBaseCurrency;
    vars.collateralItemDebtToCover = vars.collateralTotalDebtToCover / liqVars.userCollateralBalance;

    // using highest price as final liquidate price, all price and debt are based on base currency
    if (vars.collateralBonusPrice > vars.collateralItemDebtToCover) {
      vars.collateralLiquidatePrice = vars.collateralBonusPrice;
    } else {
      vars.collateralLiquidatePrice = vars.collateralItemDebtToCover;
    }

    vars.debtAmountNeeded = ((vars.collateralLiquidatePrice * params.collateralTokenIds.length * vars.debtAssetUnit) /
      (vars.debtAssetPrice * vars.collateralAssetUnit));

    return (vars.debtAmountNeeded);
  }
}
