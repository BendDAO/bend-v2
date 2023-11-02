// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library InputTypes {
  struct CalculateGroupBorrowRateParams {
    address assetAddress;
    uint256 borrowUsageRatio;
  }

  struct ExecuteDepositERC20Params {
    uint32 poolId;
    address asset;
    uint256 amount;
  }

  struct ExecuteWithdrawERC20Params {
    uint32 poolId;
    address asset;
    uint256 amount;
    address to;
  }

  struct ExecuteDepositERC721Params {
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    uint256 supplyMode;
  }

  struct ExecuteWithdrawERC721Params {
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    address to;
  }

  struct ExecuteBorrowERC20Params {
    uint32 poolId;
    address asset;
    uint256 amount;
    address to;
  }

  struct ExecuteRepayERC20Params {
    uint32 poolId;
    address asset;
    uint256 amount;
  }

  struct ExecuteLiquidateERC20Params {
    uint32 poolId;
    address user;
    address collateralAsset;
    address debtAsset;
    uint256 debtToCover;
    bool supplyAsCollateral;
  }

  struct ExecuteLiquidateERC721Params {
    uint32 poolId;
    address user;
    address collateralAsset;
    uint256[] collateralTokenIds;
    address debtAsset;
    bool supplyAsCollateral;
  }
}
