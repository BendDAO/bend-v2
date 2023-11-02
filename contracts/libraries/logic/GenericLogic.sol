// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IPriceOracleGetter} from '../../interfaces/IPriceOracleGetter.sol';

import {PercentageMath} from '../math/PercentageMath.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {DataTypes} from '../types/DataTypes.sol';

import {InterestLogic} from './InterestLogic.sol';

/**
 * @title GenericLogic library
 * @notice Implements protocol-level logic to calculate and validate the state of a user
 */
library GenericLogic {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct CalculateUserAccountDataVars {
    uint256 assetIndex;
    address currentAssetAddress;
    uint256 groupIndex;
    uint8 currentGroupId;
    uint256 assetPrice;
    uint256 assetUnit;
    uint256 userBalanceInBaseCurrency;
    // used for return variables
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLtv;
    uint256 avgLiquidationThreshold;
    uint256 healthFactor;
    bool hasZeroLtvCollateral;
  }

  /**
   * @notice Calculates the user data across the reserves.
   * @dev It includes the total liquidity/collateral/borrow balances in the base currency used by the price feed,
   * the average Loan To Value, the average Liquidation Ratio, and the Health factor.
   * @return The total collateral of the user in the base currency used by the price feed
   * @return The total debt of the user in the base currency used by the price feed
   * @return The average ltv of the user
   * @return The average liquidation threshold of the user
   * @return The health factor of the user
   * @return True if the ltv is zero, false otherwise
   */
  function calculateUserAccountData(
    DataTypes.PoolData storage poolData,
    address userAccount,
    address oracle
  ) internal view returns (uint256, uint256, uint256, uint256, uint256, bool) {
    DataTypes.AccountData storage accountData = poolData.accountLookup[userAccount];

    if (accountData.suppliedAssets.length == 0 && accountData.borrowedAssets.length == 0) {
      return (0, 0, 0, 0, type(uint256).max, false);
    }

    CalculateUserAccountDataVars memory vars;

    // calculate the sum of all the collateral balance denominated in the base currency
    for (vars.assetIndex = 0; vars.assetIndex < accountData.suppliedAssets.length; vars.assetIndex++) {
      vars.currentAssetAddress = accountData.suppliedAssets[vars.assetIndex];
      if (vars.currentAssetAddress == address(0)) {
        continue;
      }

      DataTypes.AssetData storage currentAssetData = poolData.assetLookup[vars.currentAssetAddress];

      vars.assetUnit = 10 ** currentAssetData.underlyingDecimals;
      vars.assetPrice = IPriceOracleGetter(oracle).getAssetPrice(vars.currentAssetAddress);

      if (currentAssetData.liquidationThreshold != 0) {
        vars.userBalanceInBaseCurrency = _getUserBalanceInBaseCurrency(
          userAccount,
          currentAssetData,
          vars.assetPrice,
          vars.assetUnit
        );

        vars.totalCollateralInBaseCurrency += vars.userBalanceInBaseCurrency;

        if (currentAssetData.collateralFactor != 0) {
          vars.avgLtv += vars.userBalanceInBaseCurrency * currentAssetData.collateralFactor;
        } else {
          vars.hasZeroLtvCollateral = true;
        }

        vars.avgLiquidationThreshold += vars.userBalanceInBaseCurrency * currentAssetData.liquidationThreshold;
      }
    }

    // calculate the sum of all the debt balance denominated in the base currency
    for (vars.assetIndex = 0; vars.assetIndex < accountData.borrowedAssets.length; vars.assetIndex++) {
      vars.currentAssetAddress = accountData.borrowedAssets[vars.assetIndex];
      if (vars.currentAssetAddress == address(0)) {
        continue;
      }

      DataTypes.AssetData storage currentAssetData = poolData.assetLookup[vars.currentAssetAddress];

      vars.assetUnit = 10 ** currentAssetData.underlyingDecimals;
      vars.assetPrice = IPriceOracleGetter(oracle).getAssetPrice(vars.currentAssetAddress);

      for (vars.groupIndex = 0; vars.groupIndex < currentAssetData.groupList.length; vars.groupIndex++) {
        vars.currentGroupId = currentAssetData.groupList[vars.groupIndex];
        DataTypes.GroupData storage currentGroupData = currentAssetData.groupLookup[vars.currentGroupId];

        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          userAccount,
          currentGroupData,
          vars.assetPrice,
          vars.assetUnit
        );
      }
    }

    // calculate the average LTV and Liquidation threshold
    vars.avgLtv = vars.totalCollateralInBaseCurrency != 0 ? vars.avgLtv / vars.totalCollateralInBaseCurrency : 0;
    vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency != 0
      ? vars.avgLiquidationThreshold / vars.totalCollateralInBaseCurrency
      : 0;

    // calculate the health factor
    vars.healthFactor = (vars.totalDebtInBaseCurrency == 0)
      ? type(uint256).max
      : (vars.totalCollateralInBaseCurrency.percentMul(vars.avgLiquidationThreshold)).wadDiv(
        vars.totalDebtInBaseCurrency
      );

    return (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLtv,
      vars.avgLiquidationThreshold,
      vars.healthFactor,
      vars.hasZeroLtvCollateral
    );
  }

  /**
   * @notice Calculates the maximum amount that can be borrowed depending on the available collateral, the total debt
   * and the average Loan To Value
   * @param ltv The average loan to value
   * @return The amount available to borrow in the base currency of the used by the price feed
   */
  function calculateAvailableBorrows(
    uint256 totalCollateralInBaseCurrency,
    uint256 totalDebtInBaseCurrency,
    uint256 ltv
  ) internal pure returns (uint256) {
    uint256 availableBorrowsInBaseCurrency = totalCollateralInBaseCurrency.percentMul(ltv);

    if (availableBorrowsInBaseCurrency < totalDebtInBaseCurrency) {
      return 0;
    }

    availableBorrowsInBaseCurrency = availableBorrowsInBaseCurrency - totalDebtInBaseCurrency;
    return availableBorrowsInBaseCurrency;
  }

  /**
   * @notice Calculates total debt of the user in the based currency used to normalize the values of the assets
   */
  function _getUserDebtInBaseCurrency(
    address userAccount,
    DataTypes.GroupData storage groupData,
    uint256 assetPrice,
    uint256 assetUnit
  ) private view returns (uint256) {
    // fetching variable debt
    uint256 userTotalDebt = groupData.userCrossBorrowed[userAccount];
    if (userTotalDebt != 0) {
      uint256 normalizedIndex = InterestLogic.getNormalizedBorrowDebt(groupData);
      userTotalDebt = userTotalDebt.rayMul(normalizedIndex);
      userTotalDebt = assetPrice * userTotalDebt;
    }

    return userTotalDebt / assetUnit;
  }

  /**
   * @notice Calculates total aToken balance of the user in the based currency used by the price oracle
   * @return The total aToken balance of the user normalized to the base currency of the price oracle
   */
  function _getUserBalanceInBaseCurrency(
    address userAccount,
    DataTypes.AssetData storage assetData,
    uint256 assetPrice,
    uint256 assetUnit
  ) private view returns (uint256) {
    uint256 userTotalBalance = assetData.userCrossSupplied[userAccount];
    if (userTotalBalance != 0) {
      uint256 normalizedIndex = InterestLogic.getNormalizedSupplyIncome(assetData);
      userTotalBalance = userTotalBalance.rayMul(normalizedIndex);
      userTotalBalance = assetPrice * userTotalBalance;
    }

    return userTotalBalance / assetUnit;
  }
}
