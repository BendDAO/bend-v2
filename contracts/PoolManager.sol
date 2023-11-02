// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

import './libraries/helpers/Constants.sol';
import './libraries/helpers/Errors.sol';
import './libraries/types/DataTypes.sol';
import './libraries/types/InputTypes.sol';

import './libraries/logic/StorageSlot.sol';
import './libraries/logic/VaultLogic.sol';
import './libraries/logic/SupplyLogic.sol';
import './libraries/logic/BorrowLogic.sol';
import './libraries/logic/LiquidationLogic.sol';

contract PoolManager is PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  constructor() {
    _disableInitializers();
  }

  function initialize(address aclManager_, address priceOracle_) public initializer {
    __Pausable_init();
    __ReentrancyGuard_init();

    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    cs.aclManager = aclManager_;
    cs.priceOracle = priceOracle_;

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    ps.nextPoolId = 1;
  }

  function createPool() public returns (uint32 poolId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    require(poolId > 0, Errors.CE_INVALID_POOL_ID);

    poolId = ps.nextPoolId;
    ps.nextPoolId += 1;

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    pool.poolId = poolId;
  }

  function addAssetERC20(uint32 poolId, address underlyingAsset, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    require(pool.poolId != 0, Errors.PE_POOL_NOT_EXISTS);

    DataTypes.AssetData storage asset = pool.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.PE_ASSET_ALREADY_EXISTS);

    asset.assetType = uint8(Constants.ASSET_TYPE_ERC20);
    asset.groupId = groupId;

    pool.assetList.push(underlyingAsset);
  }

  function addAssetERC721(uint32 poolId, address underlyingAsset, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    DataTypes.AssetData storage asset = pool.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.PE_ASSET_ALREADY_EXISTS);

    asset.assetType = uint8(Constants.ASSET_TYPE_ERC721);
    asset.groupId = groupId;

    pool.assetList.push(underlyingAsset);
  }

  function addGroup(uint32 poolId, address underlyingAsset, address rateModel_) public returns (uint8 groupId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    require(pool.poolId != 0, Errors.PE_POOL_NOT_EXISTS);

    DataTypes.AssetData storage assetData = pool.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.PE_ASSET_NOT_EXISTS);

    groupId = assetData.nextGroupId;
    assetData.nextGroupId += 1;

    DataTypes.GroupData storage group = assetData.groupLookup[groupId];
    group.interestRateModelAddress = rateModel_;

    assetData.groupList.push(groupId);
  }

  function depositERC20(uint32 poolId, address asset, uint256 amount) public {
    SupplyLogic.executeDepositERC20(
      InputTypes.ExecuteDepositERC20Params({poolId: poolId, asset: asset, amount: amount})
    );
  }

  function withdrawERC20(uint32 poolId, address asset, uint256 amount, address to) public {
    SupplyLogic.executeWithdrawERC20(
      InputTypes.ExecuteWithdrawERC20Params({poolId: poolId, asset: asset, amount: amount, to: to})
    );
  }

  function depositERC721(uint32 poolId, address asset, uint256[] calldata tokenIds, uint256 supplyMode) public {
    SupplyLogic.executeDepositERC721(
      InputTypes.ExecuteDepositERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds, supplyMode: supplyMode})
    );
  }

  function withdrawERC721(uint32 poolId, address asset, uint256[] calldata tokenIds, address to) public {
    SupplyLogic.executeWithdrawERC721(
      InputTypes.ExecuteWithdrawERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds, to: to})
    );
  }

  function borrowERC20(uint32 poolId, address asset, uint256 amount, address to) public {
    BorrowLogic.executeBorrowERC20(
      InputTypes.ExecuteBorrowERC20Params({poolId: poolId, asset: asset, amount: amount, to: to})
    );
  }

  function repayERC20(uint32 poolId, address asset, uint256 amount) public {
    BorrowLogic.executeRepayERC20(InputTypes.ExecuteRepayERC20Params({poolId: poolId, asset: asset, amount: amount}));
  }

  function liquidateERC20(
    uint32 poolId,
    address user,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    bool supplyAsCollateral
  ) public virtual {
    LiquidationLogic.executeLiquidateERC20(
      InputTypes.ExecuteLiquidateERC20Params({
        poolId: poolId,
        user: user,
        collateralAsset: collateralAsset,
        debtAsset: debtAsset,
        debtToCover: debtToCover,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }

  function liquidateERC721(
    uint32 poolId,
    address user,
    address collateralAsset,
    uint256[] calldata collateralTokenIds,
    address debtAsset,
    bool supplyAsCollateral
  ) public virtual {
    LiquidationLogic.executeLiquidateERC721(
      InputTypes.ExecuteLiquidateERC721Params({
        poolId: poolId,
        user: user,
        collateralAsset: collateralAsset,
        collateralTokenIds: collateralTokenIds,
        debtAsset: debtAsset,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }

  function borrowERC20WithIsolateMode(address nftAsset, uint256 nftTokenid, address asset, uint256 amount) public {}

  function repayERC20WithIsolateMode(address nftAsset, uint256 nftTokenid, address asset, uint256 amount) public {}
}
