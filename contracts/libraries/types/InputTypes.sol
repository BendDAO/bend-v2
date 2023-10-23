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
    address onBehalfOf;
  }

  struct ExecuteWithdrawERC20Params {
    uint32 poolId;
    address asset;
    uint256 amount;
    address to;
    address onBehalfOf;
  }

  struct ExecuteDepositERC721Params {
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    uint256 supplyMode;
    address onBehalfOf;
  }

  struct ExecuteWithdrawERC721Params {
    uint32 poolId;
    address asset;
    uint256[] tokenIds;
    address to;
    address onBehalfOf;
  }
}
