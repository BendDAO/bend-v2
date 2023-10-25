// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';

library SupplyLogic {
  event DepositERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event WithdrawERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  event DepositERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);
  event WithdrawERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);

  function executeDepositERC20(InputTypes.ExecuteDepositERC20Params memory params) external {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = poolData.groupLookup[assetData.groupId];

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    InterestLogic.updateInterestIndexs(assetData, groupData);

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    assetData.totalCrossSupplied += params.amount;
    assetData.userCrossSupplied[msg.sender] += params.amount;

    InterestLogic.updateInterestRates(
      poolData,
      params.asset,
      assetData,
      assetData.groupId,
      groupData,
      params.amount,
      0
    );

    emit DepositERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeWithdrawERC20(InputTypes.ExecuteWithdrawERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = poolData.groupLookup[assetData.groupId];

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    InterestLogic.updateInterestIndexs(assetData, groupData);

    // TODO: check if the user has enough collateral to cover debt

    assetData.totalCrossSupplied -= params.amount;
    assetData.userCrossSupplied[msg.sender] -= params.amount;

    VaultLogic.erc20TransferOut(params.asset, params.to, params.amount);

    InterestLogic.updateInterestRates(
      poolData,
      params.asset,
      assetData,
      assetData.groupId,
      groupData,
      0,
      params.amount
    );

    emit WithdrawERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeDepositERC721(InputTypes.ExecuteDepositERC721Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetStorage = pool.assetLookup[params.asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC721, Errors.PE_ASSET_NOT_EXISTS);

    VaultLogic.erc721TransferIn(params.asset, msg.sender, params.tokenIds);

    for (uint256 i = 0; i < params.tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetStorage.erc721TokenData[params.tokenIds[i]];
      tokenData.owner = msg.sender;
      tokenData.supplyMode = uint8(params.supplyMode);
    }

    if (params.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      assetStorage.totalCrossSupplied += params.tokenIds.length;
      assetStorage.userCrossSupplied[msg.sender] += params.tokenIds.length;
    } else if (params.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      assetStorage.totalIsolateSupplied += params.tokenIds.length;
      assetStorage.userIsolateSupplied[msg.sender] += params.tokenIds.length;
    } else {
      revert(Errors.CE_INVALID_SUPPLY_MODE);
    }

    emit DepositERC721(msg.sender, params.poolId, params.asset, params.tokenIds);
  }

  function executeWithdrawERC721(InputTypes.ExecuteWithdrawERC721Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage pool = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetStorage = pool.assetLookup[params.asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC721, Errors.PE_ASSET_NOT_EXISTS);

    for (uint256 i = 0; i < params.tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetStorage.erc721TokenData[params.tokenIds[i]];
      require(tokenData.owner == msg.sender, Errors.CE_INVALID_CALLER);
      tokenData.owner = address(0);
      tokenData.supplyMode = 0;
    }

    VaultLogic.erc721TransferOut(params.asset, params.to, params.tokenIds);

    // TODO: check if the user has enough collateral to cover debt

    emit WithdrawERC721(msg.sender, params.poolId, params.asset, params.tokenIds);
  }
}
