// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library ResultTypes {
    struct UserAccountResult {
      uint256 totalCollateralInBaseCurrency;
      uint256 inputCollateralInBaseCurrency;
      uint256 totalDebtInBaseCurrency;
      address highestDebtAsset;
      uint256 highestDebtInBaseCurrency;
      uint256 avgLtv;
      uint256 avgLiquidationThreshold;
      uint256 healthFactor;
      bool hasZeroLtvCollateral;
    }
}