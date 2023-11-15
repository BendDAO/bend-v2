// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
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
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

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

    require(poolData.assetList.length() == 0, Errors.ASSET_LIST_NOT_EMPTY);

    delete ps.poolLookup[poolId];

    emit Events.DeletePool(poolId);
  }

  function executeAddPoolGroup(uint32 poolId) public returns (uint8 groupId) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.groupList.length() <= Constants.MAX_NUMBER_OF_GROUP, Errors.GROUP_NUMBER_EXCEED_MAX_LIMIT);

    groupId = poolData.nextGroupId;
    poolData.nextGroupId++;

    poolData.enabledGroups[groupId] = true;
    bool isAddOk = poolData.groupList.add(groupId);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

    emit Events.AddPoolGroup(poolId, groupId);
  }

  function executeRemovePoolGroup(uint32 poolId, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.enabledGroups[groupId] == true, Errors.GROUP_NOT_EXISTS);

    // check all assets not belong to this group
    address[] memory allAssets = poolData.assetList.values();
    for (uint256 i = 0; i < allAssets.length; i++) {
      require(poolData.assetLookup[allAssets[i]].riskGroupId != groupId, Errors.GROUP_HAS_ASSET);
    }

    poolData.enabledGroups[groupId] = false;

    bool isDelOk = poolData.groupList.remove(groupId);
    require(isDelOk, Errors.ENUM_SET_REMOVE_FAILED);

    emit Events.RemovePoolGroup(poolId, groupId);
  }

  function executeAddAssetERC20(uint32 poolId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    require(poolData.assetList.length() <= Constants.MAX_NUMBER_OF_ASSET, Errors.ASSET_NUMBER_EXCEED_MAX_LIMIT);

    assetData.assetType = uint8(Constants.ASSET_TYPE_ERC20);
    assetData.underlyingDecimals = IERC20MetadataUpgradeable(underlyingAsset).decimals();

    InterestLogic.initAssetData(assetData);

    bool isAddOk = poolData.assetList.add(underlyingAsset);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

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

    require(poolData.assetList.length() <= Constants.MAX_NUMBER_OF_ASSET, Errors.ASSET_NUMBER_EXCEED_MAX_LIMIT);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    assetData.assetType = uint8(Constants.ASSET_TYPE_ERC721);

    bool isAddOk = poolData.assetList.add(underlyingAsset);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

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
    require(assetData.groupList.length() == 0, Errors.GROUP_LIST_NOT_EMPTY);

    bool isDelOk = poolData.assetList.remove(underlyingAsset);
    require(isDelOk, Errors.ENUM_SET_REMOVE_FAILED);
  }

  function executeAddAssetGroup(uint32 poolId, address underlyingAsset, uint8 groupId, address rateModel_) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.enabledGroups[groupId] == true, Errors.GROUP_NOT_EXISTS);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    // only erc20 asset can be borrowed
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.INVALID_ASSET_TYPE);
    require(assetData.groupList.length() <= Constants.MAX_NUMBER_OF_GROUP, Errors.GROUP_NUMBER_EXCEED_MAX_LIMIT);

    DataTypes.GroupData storage group = assetData.groupLookup[groupId];
    group.interestRateModelAddress = rateModel_;

    InterestLogic.initGroupData(group);

    bool isAddOk = assetData.groupList.add(groupId);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

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

    bool isDelOk = assetData.groupList.remove(groupId);
    require(isDelOk, Errors.ENUM_SET_REMOVE_FAILED);

    emit Events.RemoveAssetGroup(poolId, underlyingAsset, groupId);
  }

  /****************************************************************************/
  /* Asset Parameters Configuration */
  /****************************************************************************/

  function executeSetAssetActive(uint32 poolId, address underlyingAsset, bool isActive) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.isActive = isActive;

    emit Events.SetAssetActive(poolId, underlyingAsset, isActive);
  }

  function executeSetAssetFrozen(uint32 poolId, address underlyingAsset, bool isFrozen) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.isFrozen = isFrozen;

    emit Events.SetAssetFrozen(poolId, underlyingAsset, isFrozen);
  }

  function executeSetAssetPause(uint32 poolId, address underlyingAsset, bool isPause) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.isPaused = isPause;

    emit Events.SetAssetPause(poolId, underlyingAsset, isPause);
  }

  function executeSetAssetBorrowing(uint32 poolId, address underlyingAsset, bool isEnable) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[underlyingAsset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    assetData.isBorrowingEnabled = isEnable;

    emit Events.SetAssetBorrowing(poolId, underlyingAsset, isEnable);
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
