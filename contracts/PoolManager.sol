// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import './libraries/Constants.sol';
import './libraries/Errors.sol';
import './libraries/DataTypes.sol';
import './libraries/StorageSlot.sol';

contract PoolManager {
  using SafeERC20 for IERC20;

  constructor() {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    ps.nextPoolId = 1;
  }

  function createPool() public returns (uint256 poolId) {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    poolId = ps.nextPoolId;
    ps.nextPoolId += 1;

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    pool.nextGroupId = 1;
  }

  function createGroup(uint256 poolId, address rateModel_) public returns (uint256 groupId) {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    require(pool.nextGroupId != 0, Errors.PE_POOL_NOT_EXISTS);

    groupId = pool.nextGroupId;
    pool.nextGroupId += 1;

    DataTypes.Group storage group = pool.groupLookup[groupId];
    group.rateModel = rateModel_;

    pool.groupList.push(groupId);
  }

  function addAssetERC20(uint256 poolId, uint256 groupId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    require(pool.nextGroupId != 0, Errors.PE_POOL_NOT_EXISTS);

    DataTypes.Group storage group = pool.groupLookup[groupId];
    require(group.rateModel != address(0), Errors.PE_GROUP_NOT_EXISTS);

    DataTypes.Asset storage asset = pool.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.PE_ASSET_ALREADY_EXISTS);

    asset.groupId = groupId;
    asset.assetType = Constants.ASSET_TYPE_ERC20;

    pool.assetList.push(underlyingAsset);
  }

  function addAssetERC721(uint256 poolId, uint256 groupId, address underlyingAsset) public {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    //Group storage group = pool.groupLookup[groupId];
    DataTypes.Asset storage asset = pool.assetLookup[underlyingAsset];
    require(asset.assetType == 0, Errors.PE_ASSET_ALREADY_EXISTS);

    asset.groupId = groupId;
    asset.assetType = Constants.ASSET_TYPE_ERC721;

    pool.assetList.push(underlyingAsset);
  }

  function depositERC20(uint256 poolId, address asset, uint256 amount, address onBehalfOf) public {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    transferInForERC20Tokens(asset, msg.sender, amount);

    assetStorage.totalCrossSupplied += amount;
    assetStorage.userCrossSupplied[onBehalfOf] += amount;
  }

  function withdrawERC20(uint256 poolId, address asset, uint256 amount, address to) public {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    assetStorage.totalCrossSupplied -= amount;
    assetStorage.userCrossSupplied[msg.sender] -= amount;

    transferOutForERC20Tokens(asset, to, amount);

    // TODO: check if the user has enough collateral to cover debt
  }

  function depositERC721(
    uint256 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint256 supplyMode,
    address onBehalfOf
  ) public {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC721, Errors.PE_ASSET_NOT_EXISTS);

    transferInForERC721Tokens(asset, msg.sender, tokenIds);

    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetStorage.erc721TokenData[tokenIds[i]];
      tokenData.owner = onBehalfOf;
      tokenData.supplyMode = uint8(supplyMode);
    }

    if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      assetStorage.totalCrossSupplied += tokenIds.length;
      assetStorage.userCrossSupplied[onBehalfOf] += tokenIds.length;
    } else if (supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      assetStorage.totalIsolateSupplied += tokenIds.length;
      assetStorage.userIsolateSupplied[onBehalfOf] += tokenIds.length;
    } else {
      revert(Errors.CE_INVALID_SUPPLY_MODE);
    }
  }

  function withdrawERC721(uint256 poolId, address asset, uint256[] calldata tokenIds, address to) public {
    DataTypes.PoolLendingStorage storage ps = Storage.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC721, Errors.PE_ASSET_NOT_EXISTS);

    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetStorage.erc721TokenData[tokenIds[i]];
      require(tokenData.owner == msg.sender, Errors.CE_INVALID_CALLER);
      tokenData.owner = address(0);
      tokenData.supplyMode = 0;
    }

    transferOutForERC721Tokens(asset, to, tokenIds);

    // TODO: check if the user has enough collateral to cover debt
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

  function transferInForERC20Tokens(
    address underlyingAsset,
    address from,
    uint256 amount
  ) internal returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC20(underlyingAsset).balanceOf(address(this));

    IERC20(underlyingAsset).safeTransferFrom(from, address(this), amount);

    uint256 poolSizeAfter = IERC20(underlyingAsset).balanceOf(address(this));

    require(poolSizeAfter >= poolSizeBefore, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeAfter - poolSizeBefore;
    }
  }

  function transferOutForERC20Tokens(
    address underlyingAsset,
    address to,
    uint amount
  ) internal returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC20(underlyingAsset).balanceOf(address(this));

    IERC20(underlyingAsset).safeTransfer(to, amount);
    uint poolSizeAfter = IERC20(underlyingAsset).balanceOf(address(this));

    require(poolSizeBefore >= poolSizeAfter, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeBefore - poolSizeAfter;
    }
  }

  function transferInForERC721Tokens(
    address underlyingAsset,
    address from,
    uint256[] calldata tokenIds
  ) internal returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC721(underlyingAsset).balanceOf(address(this));

    for (uint256 i = 0; i < tokenIds.length; i++) {
      IERC721(underlyingAsset).safeTransferFrom(from, address(this), tokenIds[i]);
    }

    uint256 poolSizeAfter = IERC721(underlyingAsset).balanceOf(address(this));

    require(poolSizeAfter >= poolSizeBefore, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeAfter - poolSizeBefore;
    }
  }

  function transferOutForERC721Tokens(
    address underlyingAsset,
    address to,
    uint256[] calldata tokenIds
  ) internal returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC721(underlyingAsset).balanceOf(address(this));

    for (uint256 i = 0; i < tokenIds.length; i++) {
      IERC721(underlyingAsset).safeTransferFrom(address(this), to, tokenIds[i]);
    }

    uint poolSizeAfter = IERC721(underlyingAsset).balanceOf(address(this));

    require(poolSizeBefore >= poolSizeAfter, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeBefore - poolSizeAfter;
    }
  }
}
