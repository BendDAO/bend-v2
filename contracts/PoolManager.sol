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

  function createPool() public returns (uint256 poolId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    poolId = ps.nextPoolId;
    ps.nextPoolId += 1;

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    pool.nextGroupId = 1;
  }

  function createGroup(uint256 poolId, address rateModel_) public returns (uint256 groupId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    require(pool.nextGroupId != 0, Errors.PE_POOL_NOT_EXISTS);

    groupId = pool.nextGroupId;
    pool.nextGroupId += 1;

    DataTypes.GroupData storage group = pool.groupLookup[groupId];
    group.interestRateModelAddress = rateModel_;

    pool.groupList.push(groupId);
  }

  function addAssetERC20(uint256 poolId, uint256 groupId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    require(pool.nextGroupId != 0, Errors.PE_POOL_NOT_EXISTS);

    DataTypes.GroupData storage group = pool.groupLookup[groupId];
    require(group.interestRateModelAddress != address(0), Errors.PE_GROUP_NOT_EXISTS);

    DataTypes.AssetData storage asset = pool.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.PE_ASSET_ALREADY_EXISTS);

    asset.groupId = groupId;
    asset.assetType = Constants.ASSET_TYPE_ERC20;

    pool.assetList.push(underlyingAsset);
  }

  function addAssetERC721(uint256 poolId, uint256 groupId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[poolId];
    //Group storage groupData = pool.groupLookup[groupId];
    DataTypes.AssetData storage asset = pool.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.PE_ASSET_ALREADY_EXISTS);

    asset.groupId = groupId;
    asset.assetType = Constants.ASSET_TYPE_ERC721;

    pool.assetList.push(underlyingAsset);
  }

  function depositERC20(uint256 poolId, address asset, uint256 amount, address onBehalfOf) public {
    SupplyLogic.executeDepositERC20(
      InputTypes.ExecuteDepositERC20Params({poolId: poolId, asset: asset, amount: amount, onBehalfOf: onBehalfOf})
    );
  }

  function withdrawERC20(uint256 poolId, address asset, uint256 amount, address to) public {
    SupplyLogic.executeWithdrawERC20(
      InputTypes.ExecuteWithdrawERC20Params({poolId: poolId, asset: asset, amount: amount, to: to})
    );
  }

  function depositERC721(
    uint256 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint256 supplyMode,
    address onBehalfOf
  ) public {
    SupplyLogic.executeDepositERC721(
      InputTypes.ExecuteDepositERC721Params({
        poolId: poolId,
        asset: asset,
        tokenIds: tokenIds,
        supplyMode: supplyMode,
        onBehalfOf: onBehalfOf
      })
    );
  }

  function withdrawERC721(uint256 poolId, address asset, uint256[] calldata tokenIds, address to) public {
    SupplyLogic.executeWithdrawERC721(
      InputTypes.ExecuteWithdrawERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds, to: to})
    );
  }

  function borrowERC20(uint256 poolId, address asset, uint256 amount, address onBehalfOf) public {}

  function repayERC20(uint256 poolId, address asset, uint256 amount, address onBehalfOf) public {}

  function borrowERC20WithIsolateMode(
    address nftAsset,
    uint256 nftTokenid,
    address asset,
    uint256 amount,
    address onBehalfOf
  ) public {}

  function repayERC20WithIsolateMode(
    address nftAsset,
    uint256 nftTokenid,
    address asset,
    uint256 amount,
    address onBehalfOf
  ) public {}
}
