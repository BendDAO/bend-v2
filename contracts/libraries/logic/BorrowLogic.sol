// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';

library BorrowLogic {
  event BorrowERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event RepayERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  function executeBorrowERC20(InputTypes.ExecuteBorrowERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = poolData.groupLookup[assetData.groupId];

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    InterestLogic.updateInterestIndexs(assetData, groupData);

    // TODO: check if the user has enough collateral to cover debt

    groupData.totalCrossBorrowed += params.amount;
    groupData.userCrossBorrowed[msg.sender] += params.amount;

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

    emit BorrowERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeRepayERC20(InputTypes.ExecuteRepayERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = poolData.groupLookup[assetData.groupId];

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    InterestLogic.updateInterestIndexs(assetData, groupData);

    // TODO: check if the user has enough collateral to cover debt

    groupData.totalCrossBorrowed -= params.amount;
    groupData.userCrossBorrowed[msg.sender] -= params.amount;

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    InterestLogic.updateInterestRates(
      poolData,
      params.asset,
      assetData,
      assetData.groupId,
      groupData,
      0,
      params.amount
    );

    emit RepayERC20(msg.sender, params.poolId, params.asset, params.amount);
  }
}
