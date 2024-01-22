// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library InputTypes {
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
    uint8 supplyMode;
  }

  struct ExecuteSetERC721SupplyModeParams {
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    uint8 supplyMode;
  }

  // Cross Lending

  struct ExecuteCrossBorrowERC20Params {
    uint32 poolId;
    address asset;
    uint8[] groups;
    uint256[] amounts;
  }

  struct ExecuteCrossRepayERC20Params {
    uint32 poolId;
    address asset;
    uint8[] groups;
    uint256[] amounts;
  }

  struct ExecuteCrossLiquidateERC20Params {
    uint32 poolId;
    address user;
    address collateralAsset;
    address debtAsset;
    uint256 debtToCover;
    bool supplyAsCollateral;
  }

  struct ExecuteCrossLiquidateERC721Params {
    uint32 poolId;
    address user;
    address collateralAsset;
    uint256[] collateralTokenIds;
    address debtAsset;
    bool supplyAsCollateral;
  }

  // Isolate Lending

  struct ExecuteIsolateBorrowParams {
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    uint256[] amounts;
  }

  struct ExecuteIsolateRepayParams {
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    uint256[] amounts;
  }

  struct ExecuteIsolateAuctionParams {
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    uint256[] amounts;
  }

  struct ExecuteIsolateRedeemParams {
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
  }

  struct ExecuteIsolateLiquidateParams {
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    bool supplyAsCollateral;
  }

  // Yield

  struct ExecuteYieldBorrowERC20Params {
    uint32 poolId;
    address asset;
    uint256 amount;
    bool isExternalCaller;
  }

  struct ExecuteYieldRepayERC20Params {
    uint32 poolId;
    address asset;
    uint256 amount;
    bool isExternalCaller;
  }

  // Misc
  struct ExecuteFlashLoanERC721Params {
    uint32 poolId;
    address[] nftAssets;
    uint256[] nftTokenIds;
    address receiverAddress;
    bytes params;
  }
}
