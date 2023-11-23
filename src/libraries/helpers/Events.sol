// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Events {
  event AssetAggregatorUpdated(address asset, address aggregator);
  event BendNFTOracleUpdated(address bendNFTOracle);

  event CreatePool(uint32 indexed poolId);
  event DeletePool(uint32 indexed poolId);

  event AddPoolGroup(uint32 indexed poolId, uint8 groupId);
  event RemovePoolGroup(uint32 indexed poolId, uint8 groupId);

  event SetPoolYieldGroup(uint32 poolId, bool isEnable);

  event AddAsset(uint32 indexed poolId, address indexed asset, uint8 assetType);
  event RemoveAsset(uint32 indexed poolId, address indexed asset, uint8 assetType);

  event AddAssetGroup(uint32 indexed poolId, address indexed asset, uint8 groupId);
  event RemoveAssetGroup(uint32 indexed poolId, address indexed asset, uint8 groupId);
  event SetAssetInterestRateModel(uint32 indexed poolId, address indexed asset, uint8 groupId, address rateModel);

  event SetAssetActive(uint32 poolId, address asset, bool isActive);
  event SetAssetFrozen(uint32 poolId, address asset, bool isFrozen);
  event SetAssetPause(uint32 poolId, address asset, bool isPause);
  event SetAssetBorrowing(uint32 poolId, address asset, bool isEnable);
  event SetAssetSupplyCap(uint32 poolId, address asset, uint256 newCap);
  event SetAssetBorrowCap(uint32 poolId, address asset, uint256 newCap);
  event SetAssetClassGroup(uint32 indexed poolId, address indexed asset, uint8 groupId);
  event SetAssetCollateralParams(
    uint32 poolId,
    address asset,
    uint16 collateralFactor,
    uint16 liquidationThreshold,
    uint16 liquidationBonus
  );
  event SetAssetProtocolFee(uint32 poolId, address asset, uint16 feeFactor);

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

  event BorrowERC20ForYield(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event RepayERC20ForYield(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
}
