// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {IERC20MetadataUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol';
import {SafeCastUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import {IInterestRateModel} from '../../interfaces/IInterestRateModel.sol';

import {MathUtils} from '..//math/MathUtils.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {Errors} from '../helpers/Errors.sol';
import {Constants} from '../helpers/Constants.sol';
import {Events} from '../helpers/Events.sol';

import {DataTypes} from '../types/DataTypes.sol';
import {InputTypes} from '../types/InputTypes.sol';

import {StorageSlot} from './StorageSlot.sol';
import {InterestLogic} from './InterestLogic.sol';

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

    require(ps.nextPoolId > 0, Errors.INVALID_POOL_ID);

    poolId = ps.nextPoolId;
    ps.nextPoolId += 1;

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    poolData.poolId = poolId;
    poolData.governanceAdmin = msg.sender;
    poolData.nextGroupId = 1;

    emit Events.CreatePool(poolId);
  }

  function executeDeletePool(uint32 poolId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.assetList.length == 0, Errors.ASSET_LIST_NOT_EMPTY);

    delete ps.poolLookup[poolId];

    emit Events.DeletePool(poolId);
  }

  function executeAddPoolGroup(uint32 poolId) public returns (uint8 groupId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.groupList.length <= Constants.MAX_NUMBER_OF_GROUP, Errors.GROUP_NUMBER_EXCEED_MAX_LIMIT);

    groupId = poolData.nextGroupId;
    poolData.nextGroupId++;

    poolData.enabledGroups[groupId] = true;
    poolData.groupList.push(groupId);

    emit Events.AddPoolGroup(poolId, groupId);
  }

  function executeRemovePoolGroup(uint32 poolId, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.enabledGroups[groupId] == true, Errors.GROUP_NOT_EXISTS);

    // check all assets not belong to this group
    for (uint256 i = 0; i < poolData.assetList.length; i++) {
      require(poolData.assetLookup[poolData.assetList[i]].riskGroupId != groupId, Errors.GROUP_HAS_ASSET);
    }

    poolData.enabledGroups[groupId] = false;

    emit Events.RemovePoolGroup(poolId, groupId);
  }

  function executeAddAssetERC20(uint32 poolId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    require(poolData.assetList.length <= Constants.MAX_NUMBER_OF_ASSET, Errors.ASSET_NUMBER_EXCEED_MAX_LIMIT);

    assetData.assetType = uint8(Constants.ASSET_TYPE_ERC20);
    assetData.underlyingDecimals = IERC20MetadataUpgradeable(underlyingAsset).decimals();

    InterestLogic.initAssetData(assetData);

    poolData.assetList.push(underlyingAsset);

    emit Events.AddAsset(poolId, underlyingAsset, uint8(Constants.ASSET_TYPE_ERC20));
  }

  function executeRemoveAssetERC20(uint32 poolId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];

    _removeAsset(poolData, assetData, underlyingAsset);

    emit Events.RemoveAsset(poolId, underlyingAsset, uint8(Constants.ASSET_TYPE_ERC20));
  }

  function executeAddAssetERC721(uint32 poolId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.assetList.length <= Constants.MAX_NUMBER_OF_ASSET, Errors.ASSET_NUMBER_EXCEED_MAX_LIMIT);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    assetData.assetType = uint8(Constants.ASSET_TYPE_ERC721);

    poolData.assetList.push(underlyingAsset);

    emit Events.AddAsset(poolId, underlyingAsset, uint8(Constants.ASSET_TYPE_ERC721));
  }

  function executeRemoveAssetERC721(uint32 poolId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];

    _removeAsset(poolData, assetData, underlyingAsset);

    emit Events.RemoveAsset(poolId, underlyingAsset, uint8(Constants.ASSET_TYPE_ERC721));
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

  function executeAddAssetGroup(uint32 poolId, address underlyingAsset, uint8 groupId, address rateModel_) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.enabledGroups[groupId] == true, Errors.GROUP_NOT_EXISTS);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    // only erc20 asset can be borrowed
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.INVALID_ASSET_TYPE);
    require(assetData.groupList.length <= Constants.MAX_NUMBER_OF_GROUP, Errors.GROUP_NUMBER_EXCEED_MAX_LIMIT);

    DataTypes.GroupData storage group = assetData.groupLookup[groupId];
    group.interestRateModelAddress = rateModel_;

    InterestLogic.initGroupData(group);

    assetData.groupList.push(groupId);

    emit Events.AddAssetGroup(poolId, underlyingAsset, groupId);
  }

  function executeRemoveAssetGroup(uint32 poolId, address underlyingAsset, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

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

    emit Events.RemoveAssetGroup(poolId, underlyingAsset, groupId);
  }

  function executeSetAssetRiskGroup(uint32 poolId, address underlyingAsset, uint8 riskGroupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.riskGroupId = riskGroupId;
  }

  function executeSetAssetCollateralParams(
    uint32 poolId,
    address underlyingAsset,
    uint16 collateralFactor,
    uint16 liquidationThreshold,
    uint16 liquidationBonus
  ) public {
    require(collateralFactor <= Constants.MAX_COLLATERAL_FACTOR, Errors.INVALID_ASSET_PARAMS);
    require(liquidationThreshold <= Constants.MAX_LIQUIDATION_THRESHOLD, Errors.INVALID_ASSET_PARAMS);
    require(liquidationBonus <= Constants.MAX_LIQUIDATION_BONUS, Errors.INVALID_ASSET_PARAMS);

    require(collateralFactor <= liquidationThreshold, Errors.INVALID_ASSET_PARAMS);

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.collateralFactor = collateralFactor;
    assetData.liquidationThreshold = liquidationThreshold;
    assetData.liquidationBonus = liquidationBonus;

    emit Events.SetAssetCollateralParams(
      poolId,
      underlyingAsset,
      collateralFactor,
      liquidationThreshold,
      liquidationBonus
    );
  }

  function executeSetAssetProtocolFee(uint32 poolId, address underlyingAsset, uint16 feeFactor) public {
    require(feeFactor <= Constants.MAX_FEE_FACTOR, Errors.INVALID_ASSET_PARAMS);

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.feeFactor = feeFactor;

    emit Events.SetAssetProtocolFee(poolId, underlyingAsset, feeFactor);
  }

  function executeSetAssetInterestRateModel(
    uint32 poolId,
    address underlyingAsset,
    uint8 groupId,
    address rateModel_
  ) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    DataTypes.GroupData storage groupData = assetData.groupLookup[groupId];
    groupData.interestRateModelAddress = rateModel_;
  }

  function _validateOwnerAndPool(DataTypes.PoolData storage poolData) private view {
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);
    _onlyPoolGovernanceAdmin(poolData);
  }
}
