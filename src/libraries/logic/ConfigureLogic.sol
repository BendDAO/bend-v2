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
import {VaultLogic} from './VaultLogic.sol';

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

  function executeAddPoolGroup(uint32 poolId, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(groupId >= Constants.GROUP_ID_LEND_MIN, Errors.INVALID_GROUP_ID);
    require(groupId <= Constants.GROUP_ID_LEND_MAX, Errors.INVALID_GROUP_ID);
    require(poolData.enabledGroups[groupId] == false, Errors.GROUP_ALREADY_EXISTS);
    require(poolData.groupList.length() <= Constants.MAX_NUMBER_OF_GROUP, Errors.GROUP_NUMBER_EXCEED_MAX_LIMIT);

    poolData.enabledGroups[groupId] = true;
    bool isAddOk = poolData.groupList.add(groupId);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

    emit Events.AddPoolGroup(poolId, groupId);
  }

  function executeRemovePoolGroup(uint32 poolId, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(groupId >= Constants.GROUP_ID_LEND_MIN, Errors.INVALID_GROUP_ID);
    require(groupId <= Constants.GROUP_ID_LEND_MAX, Errors.INVALID_GROUP_ID);
    require(poolData.enabledGroups[groupId] == true, Errors.GROUP_NOT_EXISTS);

    // check this group not used by any asset in the pool
    address[] memory allAssets = poolData.assetList.values();
    for (uint256 i = 0; i < allAssets.length; i++) {
      DataTypes.AssetData storage assetData = poolData.assetLookup[allAssets[i]];
      require(assetData.classGroup != groupId, Errors.GROUP_USDED_BY_ASSET);

      DataTypes.GroupData storage groupData = assetData.groupLookup[groupId];
      VaultLogic.checkGroupHasEmptyLiquidity(groupData);
    }

    poolData.enabledGroups[groupId] = false;
    bool isDelOk = poolData.groupList.remove(groupId);
    require(isDelOk, Errors.ENUM_SET_REMOVE_FAILED);

    emit Events.RemovePoolGroup(poolId, groupId);
  }

  function executeSetPoolYieldEnable(uint32 poolId, bool isEnable) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    if (isEnable) {
      require(!poolData.isYieldEnabled, Errors.POOL_YIELD_ALREADY_ENABLE);

      poolData.isYieldEnabled = true;
      poolData.yieldGroupId = Constants.GROUP_ID_YIELD;
    } else {
      require(poolData.isYieldEnabled, Errors.POOL_YIELD_NOT_ENABLE);

      // check this group not used by any asset in the pool
      address[] memory allAssets = poolData.assetList.values();
      for (uint256 i = 0; i < allAssets.length; i++) {
        DataTypes.AssetData storage assetData = poolData.assetLookup[allAssets[i]];
        require(!assetData.isYieldEnabled, Errors.ASSET_YIELD_ALREADY_ENABLE);

        DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroupId];
        VaultLogic.checkGroupHasEmptyLiquidity(groupData);
      }

      poolData.isYieldEnabled = false;
      poolData.yieldGroupId = Constants.GROUP_ID_INVALID;
    }

    emit Events.SetPoolYieldEnable(poolId, isEnable);
  }

  function executeSetPoolYieldPause(uint32 poolId, bool isPause) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    poolData.isYieldPaused = isPause;

    emit Events.SetPoolYieldPause(poolId, isPause);
  }

  function executeAddAssetERC20(uint32 poolId, address asset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    require(poolData.assetList.length() <= Constants.MAX_NUMBER_OF_ASSET, Errors.ASSET_NUMBER_EXCEED_MAX_LIMIT);

    assetData.underlyingAsset = asset;
    assetData.assetType = uint8(Constants.ASSET_TYPE_ERC20);
    assetData.underlyingDecimals = IERC20MetadataUpgradeable(asset).decimals();

    InterestLogic.initAssetData(assetData);

    bool isAddOk = poolData.assetList.add(asset);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

    emit Events.AddAsset(poolId, asset, uint8(Constants.ASSET_TYPE_ERC20));
  }

  function executeRemoveAssetERC20(uint32 poolId, address asset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    _removeAsset(poolData, assetData, asset);

    emit Events.RemoveAsset(poolId, asset, uint8(Constants.ASSET_TYPE_ERC20));
  }

  function executeAddAssetERC721(uint32 poolId, address asset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.assetList.length() <= Constants.MAX_NUMBER_OF_ASSET, Errors.ASSET_NUMBER_EXCEED_MAX_LIMIT);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType == 0, Errors.ASSET_ALREADY_EXISTS);

    assetData.underlyingAsset = asset;
    assetData.assetType = uint8(Constants.ASSET_TYPE_ERC721);

    bool isAddOk = poolData.assetList.add(asset);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

    emit Events.AddAsset(poolId, asset, uint8(Constants.ASSET_TYPE_ERC721));
  }

  function executeRemoveAssetERC721(uint32 poolId, address asset) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    _removeAsset(poolData, assetData, asset);

    emit Events.RemoveAsset(poolId, asset, uint8(Constants.ASSET_TYPE_ERC721));
  }

  function _removeAsset(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address asset
  ) private {
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    VaultLogic.checkAssetHasEmptyLiquidity(poolData, assetData);

    bool isDelOk = poolData.assetList.remove(asset);
    require(isDelOk, Errors.ENUM_SET_REMOVE_FAILED);
  }

  function executeAddAssetGroup(uint32 poolId, address asset, uint8 groupId, address rateModel_) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    require(groupId >= Constants.GROUP_ID_LEND_MIN, Errors.INVALID_GROUP_ID);
    require(groupId <= Constants.GROUP_ID_LEND_MAX, Errors.INVALID_GROUP_ID);
    require(rateModel_ != address(0), Errors.INVALID_ADDRESS);

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.enabledGroups[groupId] == true, Errors.GROUP_NOT_EXISTS);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    // only erc20 asset can be borrowed and have rate group
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.INVALID_ASSET_TYPE);

    DataTypes.GroupData storage group = assetData.groupLookup[groupId];
    group.groupId = groupId;
    group.interestRateModelAddress = rateModel_;

    InterestLogic.initGroupData(group);

    bool isAddOk = assetData.groupList.add(groupId);
    require(isAddOk, Errors.ENUM_SET_ADD_FAILED);

    emit Events.AddAssetGroup(poolId, asset, groupId);
  }

  function executeRemoveAssetGroup(uint32 poolId, address asset, uint8 groupId) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    require(groupId >= Constants.GROUP_ID_LEND_MIN, Errors.INVALID_GROUP_ID);
    require(groupId <= Constants.GROUP_ID_LEND_MAX, Errors.INVALID_GROUP_ID);

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[groupId];

    // only erc20 asset can be borrowed and have rate group
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.INVALID_ASSET_TYPE);

    VaultLogic.checkGroupHasEmptyLiquidity(groupData);

    bool isDelOk = assetData.groupList.remove(groupId);
    require(isDelOk, Errors.ENUM_SET_REMOVE_FAILED);

    delete assetData.groupLookup[groupId];

    emit Events.RemoveAssetGroup(poolId, asset, groupId);
  }

  /****************************************************************************/
  /* Asset Parameters Configuration */
  /****************************************************************************/

  function executeSetAssetActive(uint32 poolId, address asset, bool isActive) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.isActive = isActive;

    emit Events.SetAssetActive(poolId, asset, isActive);
  }

  function executeSetAssetFrozen(uint32 poolId, address asset, bool isFrozen) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.isFrozen = isFrozen;

    emit Events.SetAssetFrozen(poolId, asset, isFrozen);
  }

  function executeSetAssetPause(uint32 poolId, address asset, bool isPause) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.isPaused = isPause;

    emit Events.SetAssetPause(poolId, asset, isPause);
  }

  function executeSetAssetBorrowing(uint32 poolId, address asset, bool isEnable) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    assetData.isBorrowingEnabled = isEnable;

    emit Events.SetAssetBorrowing(poolId, asset, isEnable);
  }

  function executeSetAssetSupplyCap(uint32 poolId, address asset, uint256 newCap) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    assetData.supplyCap = newCap;

    emit Events.SetAssetSupplyCap(poolId, asset, newCap);
  }

  function executeSetAssetBorrowCap(uint32 poolId, address asset, uint256 newCap) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    assetData.borrowCap = newCap;

    emit Events.SetAssetBorrowCap(poolId, asset, newCap);
  }

  function executeSetAssetClassGroup(uint32 poolId, address asset, uint8 classGroup) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.classGroup = classGroup;

    emit Events.SetAssetClassGroup(poolId, asset, classGroup);
  }

  function executeSetAssetCollateralParams(
    uint32 poolId,
    address asset,
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

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.collateralFactor = collateralFactor;
    assetData.liquidationThreshold = liquidationThreshold;
    assetData.liquidationBonus = liquidationBonus;

    emit Events.SetAssetCollateralParams(poolId, asset, collateralFactor, liquidationThreshold, liquidationBonus);
  }

  function executeSetAssetProtocolFee(uint32 poolId, address asset, uint16 feeFactor) public {
    require(feeFactor <= Constants.MAX_FEE_FACTOR, Errors.INVALID_ASSET_PARAMS);

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);

    assetData.feeFactor = feeFactor;

    emit Events.SetAssetProtocolFee(poolId, asset, feeFactor);
  }

  function executeSetAssetInterestRateModel(uint32 poolId, address asset, uint8 groupId, address rateModel_) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    require(rateModel_ != address(0), Errors.INVALID_ADDRESS);

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    DataTypes.GroupData storage groupData = assetData.groupLookup[groupId];
    groupData.interestRateModelAddress = rateModel_;

    emit Events.SetAssetInterestRateModel(poolId, asset, groupId, rateModel_);
  }

  function executeSetAssetYieldEnable(uint32 poolId, address asset, bool isEnable) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    require(poolData.isYieldEnabled, Errors.POOL_YIELD_NOT_ENABLE);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    if (isEnable) {
      require(!assetData.isYieldEnabled, Errors.ASSET_YIELD_ALREADY_ENABLE);
      assetData.isYieldEnabled = true;
    } else {
      require(assetData.isYieldEnabled, Errors.ASSET_YIELD_NOT_ENABLE);

      DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroupId];
      VaultLogic.checkGroupHasEmptyLiquidity(groupData);

      assetData.isYieldEnabled = false;
    }

    emit Events.SetAssetYieldEnable(poolId, asset, isEnable);
  }

  function executeSetAssetYieldPause(uint32 poolId, address asset, bool isPause) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    assetData.isYieldPaused = isPause;

    emit Events.SetAssetYieldPause(poolId, asset, isPause);
  }

  function executeSetAssetYieldCap(uint32 poolId, address asset, address staker, uint256 cap) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    _validateOwnerAndPool(poolData);

    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    DataTypes.StakerData storage stakerData = assetData.stakerLookup[staker];
    stakerData.yieldCap = cap;
  }

  function _validateOwnerAndPool(DataTypes.PoolData storage poolData) private view {
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);
    _onlyPoolGovernanceAdmin(poolData);
  }
}
