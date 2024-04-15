// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library InputTypes {
  struct ExecuteDepositERC20Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint256 amount;
  }

  struct ExecuteWithdrawERC20Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint256 amount;
  }

  struct ExecuteDepositERC721Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    uint8 supplyMode;
  }

  struct ExecuteWithdrawERC721Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    uint8 supplyMode;
  }

  struct ExecuteSetERC721SupplyModeParams {
    address msgSender;
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    uint8 supplyMode;
  }

  // Cross Lending

  struct ExecuteCrossBorrowERC20Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint8[] groups;
    uint256[] amounts;
  }

  struct ExecuteCrossRepayERC20Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint8[] groups;
    uint256[] amounts;
  }

  struct ExecuteCrossLiquidateERC20Params {
    address msgSender;
    uint32 poolId;
    address borrower;
    address collateralAsset;
    address debtAsset;
    uint256 debtToCover;
    bool supplyAsCollateral;
  }

  struct ExecuteCrossLiquidateERC721Params {
    address msgSender;
    uint32 poolId;
    address borrower;
    address collateralAsset;
    uint256[] collateralTokenIds;
    address debtAsset;
    bool supplyAsCollateral;
  }

  // Isolate Lending

  struct ExecuteIsolateBorrowParams {
    address msgSender;
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    uint256[] amounts;
  }

  struct ExecuteIsolateRepayParams {
    address msgSender;
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    uint256[] amounts;
  }

  struct ExecuteIsolateAuctionParams {
    address msgSender;
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    uint256[] amounts;
  }

  struct ExecuteIsolateRedeemParams {
    address msgSender;
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
  }

  struct ExecuteIsolateLiquidateParams {
    address msgSender;
    uint32 poolId;
    address nftAsset;
    uint256[] nftTokenIds;
    address asset;
    bool supplyAsCollateral;
  }

  // Yield

  struct ExecuteYieldBorrowERC20Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint256 amount;
    bool isExternalCaller;
  }

  struct ExecuteYieldRepayERC20Params {
    address msgSender;
    uint32 poolId;
    address asset;
    uint256 amount;
    bool isExternalCaller;
  }

  struct ExecuteYieldSetERC721TokenDataParams {
    address msgSender;
    uint32 poolId;
    address nftAsset;
    uint256 tokenId;
    bool isLock;
    address debtAsset;
    bool isExternalCaller;
  }

  // Misc
  struct ExecuteFlashLoanERC721Params {
    address msgSender;
    uint32 poolId;
    address[] nftAssets;
    uint256[] nftTokenIds;
    address receiverAddress;
    bytes params;
  }
}
