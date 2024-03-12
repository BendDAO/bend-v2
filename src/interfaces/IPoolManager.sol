// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

interface IPoolManager {
  /****************************************************************************/
  /* supply */
  /****************************************************************************/
  function depositERC20(uint32 poolId, address asset, uint256 amount) external;

  function withdrawERC20(uint32 poolId, address asset, uint256 amount) external;

  function depositERC721(uint32 poolId, address asset, uint256[] calldata tokenIds, uint8 supplyMode) external;

  function withdrawERC721(uint32 poolId, address asset, uint256[] calldata tokenIds, uint8 supplyMode) external;

  function setERC721SupplyMode(uint32 poolId, address asset, uint256[] calldata tokenIds, uint8 supplyMode) external;

  /****************************************************************************/
  /* cross lending */
  /****************************************************************************/
  function crossBorrowERC20(uint32 poolId, address asset, uint8[] calldata groups, uint256[] calldata amounts) external;

  function crossRepayERC20(uint32 poolId, address asset, uint8[] calldata groups, uint256[] calldata amounts) external;

  function crossLiquidateERC20(
    uint32 poolId,
    address user,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    bool supplyAsCollateral
  ) external;

  function crossLiquidateERC721(
    uint32 poolId,
    address user,
    address collateralAsset,
    uint256[] calldata collateralTokenIds,
    address debtAsset,
    bool supplyAsCollateral
  ) external;

  /****************************************************************************/
  /* isolate lending */
  /****************************************************************************/
  function isolateBorrow(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) external;

  function isolateRepay(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) external;

  function isolateAuction(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) external;

  function isolateRedeem(uint32 poolId, address nftAsset, uint256[] calldata nftTokenIds, address asset) external;

  function isolateLiquidate(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    bool supplyAsCollateral
  ) external;

  /****************************************************************************/
  /* Yield */
  /****************************************************************************/
  function yieldBorrowERC20(uint32 poolId, address asset, uint256 amount) external;

  function yieldRepayERC20(uint32 poolId, address asset, uint256 amount) external;

  // Misc
  function flashLoanERC721(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[] calldata nftTokenIds,
    address receiverAddress,
    bytes calldata params
  ) external;

  function collectFeeToTreasury(uint32 poolId, address[] calldata assets) external;
}
