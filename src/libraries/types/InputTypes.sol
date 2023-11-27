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
  }

  struct ExecuteDepositERC721Params {
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    uint8 supplyMode;
  }

  struct ExecuteWithdrawERC721Params {
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
  }

  struct ExecuteBorrowERC20Params {
    uint32 poolId;
    address asset;
    uint8[] groups;
    uint256[] amounts;
  }

  struct ExecuteRepayERC20Params {
    uint32 poolId;
    address asset;
    uint8[] groups;
    uint256[] amounts;
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

  struct ExecuteBorrowERC20ForYieldParams {
    uint32 poolId;
    address asset;
    uint256 amount;
    address staker;
  }

  struct ExecuteRepayERC20ForYieldParams {
    uint32 poolId;
    address asset;
    uint256 amount;
    address staker;
  }
}
