// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library ResultTypes {
    struct UserAccountResult {
      uint256 totalCollateralInBaseCurrency;
      uint256 totalDebtInBaseCurrency;
      uint256 groupCollateralInBaseCurrency;
      uint256 groupDebtInBaseCurrency;
      uint256 inputCollateralInBaseCurrency;
      address highestDebtAsset;
      uint256 highestDebtInBaseCurrency;
      uint256 avgLtv;
      uint256 avgLiquidationThreshold;
      uint256 groupAvgLtv;
      uint256 groupAvgLiquidationThreshold;
      uint256 healthFactor;
    }

    struct UserGroupResult {
      uint256 groupCollateralInBaseCurrency;
      uint256 groupDebtInBaseCurrency;
      uint256 groupAvgLtv;
      uint256 groupAvgLiquidationThreshold;
    }
}