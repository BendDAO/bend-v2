// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Events {
  /* Oracle Events */
  event AssetAggregatorUpdated(address indexed asset, address aggregator);
  event BendNFTOracleUpdated(address bendNFTOracle);

  /* Pool Events */
  event CreatePool(uint32 indexed poolId);
  event DeletePool(uint32 indexed poolId);

  event AddPoolGroup(uint32 indexed poolId, uint8 groupId);
  event RemovePoolGroup(uint32 indexed poolId, uint8 groupId);

  event SetPoolYieldEnable(uint32 indexed poolId, bool isEnable);
  event SetPoolYieldPause(uint32 indexed poolId, bool isPause);

  /* Asset Events */
  event AssetInterestSupplyDataUpdated(address indexed asset, uint256 supplyRate, uint256 supplyIndex);
  event AssetInterestBorrowDataUpdated(address indexed asset, uint256 groupId, uint256 borrowRate, uint256 borrowIndex);

  event AddAsset(uint32 indexed poolId, address indexed asset, uint8 assetType);
  event RemoveAsset(uint32 indexed poolId, address indexed asset, uint8 assetType);

  event AddAssetGroup(uint32 indexed poolId, address indexed asset, uint8 groupId);
  event RemoveAssetGroup(uint32 indexed poolId, address indexed asset, uint8 groupId);

  event SetAssetActive(uint32 indexed poolId, address indexed asset, bool isActive);
  event SetAssetFrozen(uint32 indexed poolId, address indexed asset, bool isFrozen);
  event SetAssetPause(uint32 indexed poolId, address indexed asset, bool isPause);
  event SetAssetBorrowing(uint32 indexed poolId, address indexed asset, bool isEnable);
  event SetAssetSupplyCap(uint32 indexed poolId, address indexed asset, uint256 newCap);
  event SetAssetBorrowCap(uint32 indexed poolId, address indexed asset, uint256 newCap);
  event SetAssetClassGroup(uint32 indexed poolId, address indexed asset, uint8 groupId);
  event SetAssetCollateralParams(
    uint32 indexed poolId,
    address indexed asset,
    uint16 collateralFactor,
    uint16 liquidationThreshold,
    uint16 liquidationBonus
  );
  event SetAssetProtocolFee(uint32 indexed poolId, address indexed asset, uint16 feeFactor);
  event SetAssetLendingRate(uint32 indexed poolId, address indexed asset, uint8 groupId, address rateModel);

  event SetAssetYieldEnable(uint32 indexed poolId, address indexed asset, bool isEnable);
  event SetAssetYieldPause(uint32 indexed poolId, address indexed asset, bool isPause);
  event SetAssetYieldCap(uint32 indexed poolId, address indexed asset, uint256 newCap);
  event SetAssetYieldRate(uint32 indexed poolId, address indexed asset, address rateModel);

  /* Supply Events */
  event DepositERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event WithdrawERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  event DepositERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);
  event WithdrawERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);

  // Cross Lending Events
  event CrossBorrowERC20(
    address indexed sender,
    uint256 indexed poolId,
    address indexed asset,
    uint8[] groups,
    uint256[] amounts
  );

  event CrossRepayERC20(
    address indexed sender,
    uint256 indexed poolId,
    address indexed asset,
    uint8[] groups,
    uint256[] amounts
  );

  event CrossLiquidateERC20(
    address liquidator,
    address indexed user,
    address indexed collateralAsset,
    address indexed debtAsset,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    bool supplyAsCollateral
  );

  event CrossLiquidateERC721(
    address liquidator,
    address indexed user,
    address indexed collateralAsset,
    uint256[] liquidatedCollateralTokenIds,
    bool supplyAsCollateral
  );

  // Isolate Lending Events
  event IsolateBorrow(
    address indexed sender,
    uint256 indexed poolId,
    address nftAsset,
    uint256[] tokenIds,
    address indexed asset,
    uint256[] amounts
  );

  event IsolateRepay(
    address indexed sender,
    uint256 indexed poolId,
    address nftAsset,
    uint256[] tokenIds,
    address indexed asset,
    uint256[] amounts
  );

  event IsolateAuction(
    address indexed sender,
    uint256 indexed poolId,
    address nftAsset,
    uint256[] tokenIds,
    address indexed asset,
    uint256[] amounts
  );

  event IsolateRedeem(
    address indexed sender,
    uint256 indexed poolId,
    address nftAsset,
    uint256[] tokenIds,
    address indexed asset
  );

  event IsolateLiquidate(
    address indexed sender,
    uint256 indexed poolId,
    address nftAsset,
    uint256[] tokenIds,
    address indexed asset
  );

  /* Yield Events */
  event YieldBorrowERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  event YieldRepayERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
}
