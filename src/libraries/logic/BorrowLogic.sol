// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';
import {RiskManagerLogic} from './RiskManagerLogic.sol';

library BorrowLogic {
  function executeBorrowERC20(InputTypes.ExecuteBorrowERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[assetData.riskGroupId];

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    InterestLogic.updateInterestIndexs(assetData, groupData);

    bool isFirstBorrow = VaultLogic.erc20IncreaseBorrow(groupData, msg.sender, params.amount);
    if (isFirstBorrow) {
      VaultLogic.accountAddAsset(poolData.accountLookup[msg.sender], params.asset, false);
    }

    VaultLogic.erc20TransferOut(params.asset, params.to, params.amount);

    InterestLogic.updateInterestRates(params.asset, assetData, 0, params.amount);

    // TODO: check if the user has enough collateral to cover debt
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    RiskManagerLogic.checkHealthFactor(poolData, msg.sender, cs.priceOracle);

    emit Events.BorrowERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeRepayERC20(InputTypes.ExecuteRepayERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[assetData.riskGroupId];

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    InterestLogic.updateInterestIndexs(assetData, groupData);

    bool isFullRepay = VaultLogic.erc20DecreaseBorrow(groupData, msg.sender, params.amount);
    if (isFullRepay) {
      VaultLogic.accountRemoveAsset(poolData.accountLookup[msg.sender], params.asset, false);
    }

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    InterestLogic.updateInterestRates(params.asset, assetData, 0, params.amount);

    emit Events.RepayERC20(msg.sender, params.poolId, params.asset, params.amount);
  }
}
