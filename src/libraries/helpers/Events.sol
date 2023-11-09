// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Events {
  event CreatePool(uint32 indexed poolId);
  event DeletePool(uint32 indexed poolId);

  event AddAsset(uint32 indexed poolId, address indexed underlyingAsset, uint8 assetType);
  event RemoveAsset(uint32 indexed poolId, address indexed underlyingAsset, uint8 assetType);
  event SetAssetGroup(uint32 indexed poolId, address indexed underlyingAsset, uint8 groupId);

  event AddGroup(uint32 indexed poolId, address indexed underlyingAsset, uint8 groupId);
  event RemoveGroup(uint32 indexed poolId, address indexed underlyingAsset, uint8 groupId);
  event SetGroupInterestRateModel(
    uint32 indexed poolId,
    address indexed underlyingAsset,
    uint8 groupId,
    address rateModel
  );

  event AssetInterestSupplyDataUpdated(address indexed asset, uint256 supplyRate, uint256 supplyIndex);
  event AssetInterestBorrowDataUpdated(address indexed asset, uint256 groupId, uint256 borrowRate, uint256 borrowIndex);

  event DepositERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event WithdrawERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  event DepositERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);
  event WithdrawERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);

  event BorrowERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event RepayERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  event LiquidateERC20(
    address liquidator,
    address indexed user,
    address indexed collateralAsset,
    address indexed debtAsset,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    bool supplyAsCollateral
  );

  event LiquidateERC721(
    address liquidator,
    address indexed user,
    address indexed collateralAsset,
    uint256[] liquidatedCollateralTokenIds,
    bool supplyAsCollateral
  );
}
