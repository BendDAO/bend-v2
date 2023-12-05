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
import {ValidateLogic} from './ValidateLogic.sol';

library LiquidationLogic {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct LiquidateERC20LocalVars {
    uint256 gidx;
    uint256[] assetGroupIds;
    uint256 userCollateralBalance;
    uint256 userTotalDebt;
    uint256 actualDebtToLiquidate;
    uint256 remainDebtToLiquidate;
    uint256 actualCollateralToLiquidate;
  }

  /**
   * @notice Function to liquidate a position if its Health Factor drops below 1. The caller (liquidator)
   * covers `debtToCover` amount of debt of the user getting liquidated, and receives
   * a proportional amount of the `collateralAsset` plus a bonus to cover market risk
   */
  function executeCrossLiquidateERC20(InputTypes.ExecuteCrossLiquidateERC20Params memory params) external {
    LiquidateERC20LocalVars memory vars;

    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage collateralAssetData = poolData.assetLookup[params.collateralAsset];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[params.debtAsset];

    InterestLogic.updateInterestSupplyIndex(collateralAssetData);

    // make sure debt asset's all group index updated
    vars.assetGroupIds = debtAssetData.groupList.values();
    for (vars.gidx = 0; vars.gidx < vars.assetGroupIds.length; vars.gidx++) {
      DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[uint8(vars.assetGroupIds[vars.gidx])];
      InterestLogic.updateInterestBorrowIndex(debtAssetData, debtGroupData);
    }

    ValidateLogic.validateCrossLiquidateERC20(params, poolData, collateralAssetData, debtAssetData);

    // check the user account state
    ResultTypes.UserAccountResult memory userAccountResult = GenericLogic.calculateUserAccountDataForLiquidate(
      poolData,
      params.user,
      params.collateralAsset,
      cs.priceOracle
    );

    require(
      userAccountResult.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.HEALTH_FACTOR_NOT_BELOW_LIQUIDATION_THRESHOLD
    );

    // calculate user's debt and collateral supply
    (vars.userTotalDebt, vars.actualDebtToLiquidate) = _calculateUserERC20Debt(
      poolData,
      debtAssetData,
      params,
      userAccountResult.healthFactor
    );

    vars.userCollateralBalance = VaultLogic.erc20GetUserCrossSupply(
      collateralAssetData,
      params.user,
      collateralAssetData.supplyIndex
    );

    (vars.actualCollateralToLiquidate, vars.actualDebtToLiquidate) = _calculateAvailableERC20CollateralToLiquidate(
      collateralAssetData,
      debtAssetData,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      IPriceOracleGetter(cs.priceOracle)
    );

    InterestLogic.updateInterestRates(poolData, debtAssetData, vars.actualDebtToLiquidate, 0);

    // Transfers the debt asset being repaid to the vault, where the liquidity is kept
    VaultLogic.erc20TransferInLiquidity(debtAssetData, msg.sender, vars.actualDebtToLiquidate);

    vars.remainDebtToLiquidate = _repayUserERC20Debt(poolData, debtAssetData, params.user, vars.actualDebtToLiquidate);
    require(vars.remainDebtToLiquidate == 0, Errors.LIQUIDATE_REPAY_DEBT_FAILED);

    // If all the debt has being repaid we need clear the borrow flag
    VaultLogic.accountCheckAndSetBorrowedAsset(poolData, debtAssetData, params.user);

    // Whether transfer the liquidated collateral or supplied as new collateral to liquidator
    if (params.supplyAsCollateral) {
      _supplyUserERC20CollateralToLiquidator(poolData, collateralAssetData, params, vars);
    } else {
      _transferUserERC20CollateralToLiquidator(poolData, collateralAssetData, params, vars);
    }

    // If user's all the collateral has being liquidated we need clear the supply flag
    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, collateralAssetData, params.user);

    emit Events.CrossLiquidateERC20(
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
    uint256 gidx;
    uint256[] assetGroupIds;
    uint256 userCollateralBalance;
    uint256 actualDebtToLiquidate;
    uint256 remainDebtToLiquidate;
    ResultTypes.UserAccountResult userAccountResult;
  }

  /**
   * @notice Function to liquidate a ERC721 collateral if its Health Factor drops below 1.
   */
  function executeCrossLiquidateERC721(InputTypes.ExecuteCrossLiquidateERC721Params memory params) external {
    LiquidateERC721LocalVars memory vars;

    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage collateralAssetData = poolData.assetLookup[params.collateralAsset];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[params.debtAsset];

    // make sure debt asset's all group index updated
    vars.assetGroupIds = debtAssetData.groupList.values();
    for (vars.gidx = 0; vars.gidx < vars.assetGroupIds.length; vars.gidx++) {
      DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[uint8(vars.assetGroupIds[vars.gidx])];
      InterestLogic.updateInterestBorrowIndex(debtAssetData, debtGroupData);
    }

    ValidateLogic.validateCrossLiquidateERC721(params, poolData, collateralAssetData, debtAssetData);

    vars.userAccountResult = GenericLogic.calculateUserAccountDataForLiquidate(
      poolData,
      params.collateralAsset,
      params.user,
      cs.priceOracle
    );

    require(
      vars.userAccountResult.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.HEALTH_FACTOR_NOT_BELOW_LIQUIDATION_THRESHOLD
    );

    vars.userCollateralBalance = VaultLogic.erc721GetUserCrossSupply(collateralAssetData, params.user);

    // the liquidated debt amount will be decided by the liquidated collateral
    vars.actualDebtToLiquidate = _calculateDebtAmountFromERC721Collateral(
      collateralAssetData,
      debtAssetData,
      params,
      vars,
      IPriceOracleGetter(cs.priceOracle)
    );

    InterestLogic.updateInterestRates(poolData, debtAssetData, vars.actualDebtToLiquidate, 0);

    // Transfers the debt asset being repaid to the vault, where the liquidity is kept
    VaultLogic.erc20TransferInLiquidity(debtAssetData, msg.sender, vars.actualDebtToLiquidate);

    // try to repay debt for the user, the liquidated debt amount may less than user total debt
    vars.remainDebtToLiquidate = _repayUserERC20Debt(poolData, debtAssetData, params.user, vars.actualDebtToLiquidate);
    if (vars.remainDebtToLiquidate > 0) {
      // transfer the remain debt asset to the user as new supplied collateral
      VaultLogic.erc20IncreaseCrossSupply(debtAssetData, params.user, vars.remainDebtToLiquidate);

      // If the collateral is supplied at first we need set the supply flag
      VaultLogic.accountCheckAndSetSuppliedAsset(poolData, debtAssetData, params.user);
    }

    // If all the debt has being repaid we need to clear the borrow flag
    VaultLogic.accountCheckAndSetBorrowedAsset(poolData, debtAssetData, params.user);

    // Whether transfer the liquidated collateral or supplied as new collateral to liquidator
    if (params.supplyAsCollateral) {
      _supplyUserERC721CollateralToLiquidator(poolData, collateralAssetData, params);
    } else {
      _transferUserERC721CollateralToLiquidator(collateralAssetData, params);
    }

    // If all the collateral has been liquidated we need clear the supply flag
    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, collateralAssetData, params.user);

    emit Events.CrossLiquidateERC721(
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
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteCrossLiquidateERC20Params memory params,
    LiquidateERC20LocalVars memory vars
  ) internal {
    InterestLogic.updateInterestSupplyIndex(collateralAssetData);

    // Burn the equivalent amount of collateral, sending the underlying to the liquidator
    VaultLogic.erc20DecreaseCrossSupply(collateralAssetData, params.user, vars.actualCollateralToLiquidate);

    InterestLogic.updateInterestRates(poolData, collateralAssetData, 0, vars.actualCollateralToLiquidate);

    VaultLogic.erc20TransferOutLiquidity(collateralAssetData, msg.sender, vars.actualCollateralToLiquidate);
  }

  /**
   * @notice Liquidates the user erc20 collateral by transferring them to the liquidator.
   */
  function _supplyUserERC20CollateralToLiquidator(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteCrossLiquidateERC20Params memory params,
    LiquidateERC20LocalVars memory vars
  ) internal {
    VaultLogic.erc20TransferCrossSupply(collateralAssetData, params.user, msg.sender, vars.actualCollateralToLiquidate);

    // If the collateral is supplied at first we need set the supply flag
    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, collateralAssetData, msg.sender);
  }

  /**
   * @notice Burns the debt of the user up to the amount being repaid by the liquidator.
   */
  function _repayUserERC20Debt(
    DataTypes.PoolData storage /*poolData*/,
    DataTypes.AssetData storage debtAssetData,
    address user,
    uint256 actualDebtToLiquidate
  ) internal returns (uint256) {
    // sort group id from lowest interest rate to highest
    uint256[] memory assetGroupIds = debtAssetData.groupList.values();
    KVSortUtils.KeyValue[] memory groupRateList = new KVSortUtils.KeyValue[](assetGroupIds.length);
    for (uint256 i = 0; i < groupRateList.length; i++) {
      DataTypes.GroupData storage loopGroupData = debtAssetData.groupLookup[uint8(assetGroupIds[i])];

      groupRateList[i].key = assetGroupIds[i];
      groupRateList[i].val = loopGroupData.borrowRate;
    }
    KVSortUtils.sort(groupRateList);

    // repay group debt one by one, but from highest to lowest
    uint256 remainDebtToLiquidate = actualDebtToLiquidate;
    for (uint256 i = 0; i < groupRateList.length; i++) {
      uint256 reverseIdx = (groupRateList.length - 1) - i;
      DataTypes.GroupData storage loopGroupData = debtAssetData.groupLookup[uint8(groupRateList[reverseIdx].key)];

      uint256 curDebtRepayAmount = VaultLogic.erc20GetUserCrossBorrowInGroup(
        loopGroupData,
        user,
        loopGroupData.borrowIndex
      );
      if (curDebtRepayAmount > remainDebtToLiquidate) {
        curDebtRepayAmount = remainDebtToLiquidate;
        remainDebtToLiquidate = 0;
      } else {
        remainDebtToLiquidate -= curDebtRepayAmount;
      }
      VaultLogic.erc20DecreaseCrossBorrow(loopGroupData, user, curDebtRepayAmount);

      if (remainDebtToLiquidate == 0) {
        break;
      }
    }

    return remainDebtToLiquidate;
  }

  /**
   * @notice Calculates the total debt of the user and the actual amount to liquidate depending on the health factor
   * and corresponding close factor.
   * @dev If the Health Factor is below CLOSE_FACTOR_HF_THRESHOLD, the close factor is increased to MAX_LIQUIDATION_CLOSE_FACTOR
   */
  function _calculateUserERC20Debt(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage debtAssetData,
    InputTypes.ExecuteCrossLiquidateERC20Params memory params,
    uint256 healthFactor
  ) internal view returns (uint256, uint256) {
    uint256 userTotalDebt = VaultLogic.erc20GetUserCrossBorrowInAsset(poolData, debtAssetData, params.user);

    // Whether 50% or 100% debt can be liquidated (covered)
    uint256 closeFactor = healthFactor > Constants.CLOSE_FACTOR_HF_THRESHOLD
      ? Constants.DEFAULT_LIQUIDATION_CLOSE_FACTOR
      : Constants.MAX_LIQUIDATION_CLOSE_FACTOR;

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
    uint256 debtToCover,
    uint256 userCollateralBalance,
    IPriceOracleGetter oracle
  ) internal view returns (uint256, uint256) {
    AvailableERC20CollateralToLiquidateLocalVars memory vars;

    vars.collateralPrice = oracle.getAssetPrice(collateralAssetData.underlyingAsset);
    vars.debtAssetPrice = oracle.getAssetPrice(debtAssetData.underlyingAsset);

    vars.collateralDecimals = collateralAssetData.underlyingDecimals;
    vars.debtAssetDecimals = debtAssetData.underlyingDecimals;

    vars.collateralAssetUnit = 10 ** vars.collateralDecimals;
    vars.debtAssetUnit = 10 ** vars.debtAssetDecimals;

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
    InputTypes.ExecuteCrossLiquidateERC721Params memory params
  ) internal {
    // Burn the equivalent amount of collateral, sending the underlying to the liquidator
    VaultLogic.erc721DecreaseCrossSupply(collateralAssetData, params.user, params.collateralTokenIds);

    VaultLogic.erc721TransferOutLiquidity(collateralAssetData, msg.sender, params.collateralTokenIds);
  }

  /**
   * @notice Liquidates the user erc721 collateral by transferring them to the liquidator.
   */
  function _supplyUserERC721CollateralToLiquidator(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage collateralAssetData,
    InputTypes.ExecuteCrossLiquidateERC721Params memory params
  ) internal {
    VaultLogic.erc721TransferCrossSupply(collateralAssetData, params.user, msg.sender, params.collateralTokenIds);

    // If the collateral is supplied at first we need set the supply flag
    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, collateralAssetData, msg.sender);
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
    InputTypes.ExecuteCrossLiquidateERC721Params memory params,
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
