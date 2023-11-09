// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeCastUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import {IInterestRateModel} from '../../interfaces/IInterestRateModel.sol';

import {MathUtils} from '..//math/MathUtils.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {Errors} from '../helpers/Errors.sol';
import {Constants} from '../helpers/Constants.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {InputTypes} from '../types/InputTypes.sol';

import {StorageSlot} from './StorageSlot.sol';

/**
 * @title ConfigureLogic library
 * @notice Implements the logic to configure the protocol parameters
 */
library ConfigureLogic {
  function _onlyPoolGovernanceAdmin(DataTypes.PoolData storage poolData) private view {
    require(poolData.governanceAdmin == msg.sender, Errors.INVALID_CALLER);
  }

  function executeCreatePool() public returns (uint32 poolId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    require(poolId > 0, Errors.INVALID_POOL_ID);

    poolId = ps.nextPoolId;
    ps.nextPoolId += 1;

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    poolData.poolId = poolId;
    poolData.governanceAdmin = msg.sender;
  }

  function executeAddAssetERC20(uint32 poolId, address underlyingAsset, uint8 riskGroupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);

    _onlyPoolGovernanceAdmin(poolData);

    DataTypes.AssetData storage asset = poolData.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    require(poolData.assetList.length <= Constants.MAX_NUMBER_OF_ASSET, Errors.ASSET_NUMBER_EXCEED_MAX_LIMIT);

    asset.assetType = uint8(Constants.ASSET_TYPE_ERC20);
    asset.riskGroupId = riskGroupId;

    poolData.assetList.push(underlyingAsset);
  }

  function executeRemoveAssetERC20(uint32 poolId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);

    _onlyPoolGovernanceAdmin(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];

    _removeAsset(poolData, assetData, underlyingAsset);
  }

  function executeAddAssetERC721(uint32 poolId, address underlyingAsset, uint8 riskGroupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);

    _onlyPoolGovernanceAdmin(poolData);

    DataTypes.AssetData storage asset = poolData.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    asset.assetType = uint8(Constants.ASSET_TYPE_ERC721);
    asset.riskGroupId = riskGroupId;

    poolData.assetList.push(underlyingAsset);
  }

  function executeRemoveAssetERC721(uint32 poolId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);

    _onlyPoolGovernanceAdmin(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];

    _removeAsset(poolData, assetData, underlyingAsset);
  }

  function _removeAsset(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address underlyingAsset
  ) private {
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);
    require(assetData.totalCrossSupplied == 0, Errors.CROSS_SUPPLY_NOT_EMPTY);
    require(assetData.totalIsolateSupplied == 0, Errors.ISOLATE_SUPPLY_NOT_EMPTY);
    require(assetData.groupList.length == 0, Errors.GROUP_LIST_NOT_EMPTY);

    uint assetLength = poolData.assetList.length;
    uint searchIndex = type(uint).max;
    for (uint i = 0; i < assetLength; i++) {
      if (poolData.assetList[i] == underlyingAsset) {
        searchIndex = i;
        break;
      }
    }
    require(searchIndex <= (assetLength - 1), Errors.ASSET_NOT_EXISTS);
    if (searchIndex < (assetLength - 1)) {
      poolData.assetList[searchIndex] = poolData.assetList[assetLength - 1];
    }
    poolData.assetList[assetLength - 1] = address(0);
    poolData.assetList.pop();
  }

  function executeAddGroup(uint32 poolId, address underlyingAsset, address rateModel_) public returns (uint8 groupId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);

    _onlyPoolGovernanceAdmin(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    // only erc20 asset can be borrowed
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.INVALID_ASSET_TYPE);

    groupId = assetData.nextGroupId;
    assetData.nextGroupId += 1;

    DataTypes.GroupData storage group = assetData.groupLookup[groupId];
    group.interestRateModelAddress = rateModel_;

    assetData.groupList.push(groupId);
  }

  function executeRemoveGroup(uint32 poolId, address underlyingAsset, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);

    _onlyPoolGovernanceAdmin(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[groupId];
    require(groupData.interestRateModelAddress != address(0), Errors.GROUP_NOT_EXISTS);

    require(groupData.totalCrossBorrowed == 0, Errors.CROSS_DEBT_NOT_EMPTY);
    require(groupData.totalIsolateBorrowed == 0, Errors.ISOLATE_DEBT_NOT_EMPTY);

    uint groupLength = assetData.groupList.length;
    uint searchIndex = type(uint).max;
    for (uint i = 0; i < groupLength; i++) {
      if (assetData.groupList[i] == groupId) {
        searchIndex = i;
        break;
      }
    }
    require(searchIndex <= (groupLength - 1), Errors.GROUP_NOT_EXISTS);
    if (searchIndex < (groupLength - 1)) {
      assetData.groupList[searchIndex] = assetData.groupList[groupLength - 1];
    }
    assetData.groupList[groupLength - 1] = 0;
    assetData.groupList.pop();
  }
}
