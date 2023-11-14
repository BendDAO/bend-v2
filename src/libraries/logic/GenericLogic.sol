// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

import {IPriceOracleGetter} from '../../interfaces/IPriceOracleGetter.sol';

import {PercentageMath} from '../math/PercentageMath.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {ResultTypes} from '../types/ResultTypes.sol';
import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';

import 'forge-std/console.sol';

/**
 * @title GenericLogic library
 * @notice Implements protocol-level logic to calculate and validate the state of a user
 */
library GenericLogic {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct CalculateUserAccountDataVars {
    address[] userSuppliedAssets;
    address[] userBorrowedAssets;
    uint256 assetIndex;
    address currentAssetAddress;
    uint256[] assetGroupIds;
    uint256 groupIndex;
    uint8 currentGroupId;
    uint256 assetPrice;
    uint256 userBalanceInBaseCurrency;
    uint256 userDebtInBaseCurrency;
  }

  /**
   * @notice Calculates the user data across the reserves.
   * @dev It includes the total liquidity/collateral/borrow balances in the base currency used by the price feed,
   * the average Loan To Value, the average Liquidation Ratio, and the Health factor.
   */
  function calculateUserAccountData(
    DataTypes.PoolData storage poolData,
    address userAccount,
    address collateralAsset,
    address oracle
  ) internal view returns (ResultTypes.UserAccountResult memory result) {
    CalculateUserAccountDataVars memory vars;

    DataTypes.AccountData storage accountData = poolData.accountLookup[userAccount];

    // calculate the sum of all the collateral balance denominated in the base currency
    vars.userSuppliedAssets = VaultLogic.accountGetSuppliedAssets(accountData);
    console.log('userSuppliedAssets', vars.userSuppliedAssets.length);
    for (vars.assetIndex = 0; vars.assetIndex < vars.userSuppliedAssets.length; vars.assetIndex++) {
      vars.currentAssetAddress = vars.userSuppliedAssets[vars.assetIndex];
      if (vars.currentAssetAddress == address(0)) {
        continue;
      }

      DataTypes.AssetData storage currentAssetData = poolData.assetLookup[vars.currentAssetAddress];

      vars.assetPrice = IPriceOracleGetter(oracle).getAssetPrice(vars.currentAssetAddress);

      if (currentAssetData.liquidationThreshold != 0) {
        if (currentAssetData.assetType == Constants.ASSET_TYPE_ERC20) {
          vars.userBalanceInBaseCurrency = _getUserERC20BalanceInBaseCurrency(
            userAccount,
            currentAssetData,
            vars.assetPrice
          );
        } else if (currentAssetData.assetType == Constants.ASSET_TYPE_ERC721) {
          vars.userBalanceInBaseCurrency = _getUserERC721BalanceInBaseCurrency(
            userAccount,
            currentAssetData,
            vars.assetPrice
          );
        } else {
          revert(Errors.INVALID_ASSET_TYPE);
        }
        console.log('userBalanceInBaseCurrency', vars.userBalanceInBaseCurrency);

        result.totalCollateralInBaseCurrency += vars.userBalanceInBaseCurrency;

        if (collateralAsset == vars.currentAssetAddress) {
          result.inputCollateralInBaseCurrency += vars.userBalanceInBaseCurrency;
        }

        if (currentAssetData.collateralFactor != 0) {
          result.avgLtv += vars.userBalanceInBaseCurrency * currentAssetData.collateralFactor;
        } else {
          result.hasZeroLtvCollateral = true;
        }

        result.avgLiquidationThreshold += vars.userBalanceInBaseCurrency * currentAssetData.liquidationThreshold;
      }
    }

    // calculate the sum of all the debt balance denominated in the base currency
    vars.userBorrowedAssets = VaultLogic.accountGetBorrowedAssets(accountData);
    console.log('userBorrowedAssets', vars.userBorrowedAssets.length);
    for (vars.assetIndex = 0; vars.assetIndex < vars.userBorrowedAssets.length; vars.assetIndex++) {
      vars.currentAssetAddress = vars.userBorrowedAssets[vars.assetIndex];
      if (vars.currentAssetAddress == address(0)) {
        continue;
      }

      DataTypes.AssetData storage currentAssetData = poolData.assetLookup[vars.currentAssetAddress];
      require(currentAssetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

      vars.assetPrice = IPriceOracleGetter(oracle).getAssetPrice(vars.currentAssetAddress);

      // same debt can be borrowed in different groups by different collaterals
      // e.g. BAYC borrow ETH in group 1, MAYC borrow ETH in group 2
      vars.userDebtInBaseCurrency = 0;
      vars.assetGroupIds = currentAssetData.groupList.values();
      for (vars.groupIndex = 0; vars.groupIndex < vars.assetGroupIds.length; vars.groupIndex++) {
        vars.currentGroupId = uint8(vars.assetGroupIds[vars.groupIndex]);
        DataTypes.GroupData storage currentGroupData = currentAssetData.groupLookup[vars.currentGroupId];

        vars.userDebtInBaseCurrency += _getUserERC20DebtInBaseCurrency(
          userAccount,
          currentAssetData,
          currentGroupData,
          vars.assetPrice
        );
      }

      console.log('userDebtInBaseCurrency', vars.userDebtInBaseCurrency);

      result.totalDebtInBaseCurrency += vars.userDebtInBaseCurrency;
      if (vars.userDebtInBaseCurrency > result.highestDebtInBaseCurrency) {
        result.highestDebtInBaseCurrency = vars.userDebtInBaseCurrency;
        result.highestDebtAsset = vars.currentAssetAddress;
      }
    }

    // calculate the average LTV and Liquidation threshold
    result.avgLtv = result.totalCollateralInBaseCurrency != 0
      ? result.avgLtv / result.totalCollateralInBaseCurrency
      : 0;
    result.avgLiquidationThreshold = result.totalCollateralInBaseCurrency != 0
      ? result.avgLiquidationThreshold / result.totalCollateralInBaseCurrency
      : 0;

    // calculate the health factor
    result.healthFactor = (result.totalDebtInBaseCurrency == 0)
      ? type(uint256).max
      : (result.totalCollateralInBaseCurrency.percentMul(result.avgLiquidationThreshold)).wadDiv(
        result.totalDebtInBaseCurrency
      );

    console.log('totalCollateralInBaseCurrency', result.totalCollateralInBaseCurrency);
    console.log('totalDebtInBaseCurrency', result.totalDebtInBaseCurrency);
    console.log('avgLtv', result.avgLtv);
    console.log('avgLiquidationThreshold', result.avgLiquidationThreshold);
    console.log('healthFactor', result.healthFactor);
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
  function _getUserERC20DebtInBaseCurrency(
    address userAccount,
    DataTypes.AssetData storage assetData,
    DataTypes.GroupData storage groupData,
    uint256 assetPrice
  ) private view returns (uint256) {
    // fetching variable debt
    uint256 userTotalDebt = groupData.userCrossBorrowed[userAccount];
    if (userTotalDebt != 0) {
      uint256 normalizedIndex = InterestLogic.getNormalizedBorrowDebt(groupData);
      userTotalDebt = userTotalDebt.rayMul(normalizedIndex);
      userTotalDebt = assetPrice * userTotalDebt;
    }

    return userTotalDebt / (10 ** assetData.underlyingDecimals);
  }

  /**
   * @notice Calculates total aToken balance of the user in the based currency used by the price oracle
   * @return The total aToken balance of the user normalized to the base currency of the price oracle
   */
  function _getUserERC20BalanceInBaseCurrency(
    address userAccount,
    DataTypes.AssetData storage assetData,
    uint256 assetPrice
  ) private view returns (uint256) {
    uint256 userTotalBalance = assetData.userCrossSupplied[userAccount];
    if (userTotalBalance != 0) {
      uint256 normalizedIndex = InterestLogic.getNormalizedSupplyIncome(assetData);
      userTotalBalance = userTotalBalance.rayMul(normalizedIndex);
      userTotalBalance = assetPrice * userTotalBalance;
    }

    return userTotalBalance / (10 ** assetData.underlyingDecimals);
  }

  function _getUserERC721BalanceInBaseCurrency(
    address userAccount,
    DataTypes.AssetData storage assetData,
    uint256 assetPrice
  ) private view returns (uint256) {
    uint256 userTotalBalance = assetData.userCrossSupplied[userAccount];
    if (userTotalBalance != 0) {
      userTotalBalance = assetPrice * userTotalBalance;
    }

    return userTotalBalance;
  }
}
