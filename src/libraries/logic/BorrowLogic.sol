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
import {ValidateLogic} from './ValidateLogic.sol';

library BorrowLogic {
  function executeBorrowERC20(InputTypes.ExecuteBorrowERC20Params memory params) public {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[params.group];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateBorrowERC20(params, poolData, assetData, groupData, msg.sender, cs.priceOracle);

    VaultLogic.erc20IncreaseBorrow(groupData, msg.sender, params.amount);

    VaultLogic.accountCheckAndSetBorrowedAsset(poolData, assetData, params.asset, msg.sender);

    VaultLogic.erc20TransferOut(params.asset, params.to, params.amount);

    InterestLogic.updateInterestRates(poolData, params.asset, assetData, 0, params.amount);

    emit Events.BorrowERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeRepayERC20(InputTypes.ExecuteRepayERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[params.group];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateRepayERC20(params, poolData, assetData, groupData);

    uint256 debtAmount = VaultLogic.erc20GetUserBorrowInGroup(groupData, msg.sender);
    if (debtAmount < params.amount) {
      params.amount = debtAmount;
    }

    VaultLogic.erc20DecreaseBorrow(groupData, msg.sender, params.amount);

    VaultLogic.accountCheckAndSetBorrowedAsset(poolData, assetData, params.asset, msg.sender);

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    InterestLogic.updateInterestRates(poolData, params.asset, assetData, 0, params.amount);

    emit Events.RepayERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  /**
   * @notice Implements the borrow for yield feature.
   * It allows whitelisted staker to draw liquidity from the protocol without any collateral.
   */
  function executeBorrowERC20ForYield(InputTypes.ExecuteBorrowERC20ForYieldParams memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroupId];

    DataTypes.StakerData storage stakerData = assetData.stakerLookup[params.staker];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateBorrowERC20ForYield(params, poolData, assetData, groupData);

    uint256 debtAmount = VaultLogic.erc20GetUserBorrowInGroup(groupData, msg.sender);
    require((debtAmount + params.amount) <= stakerData.yieldCap, Errors.YIELD_EXCEED_CAP_LIMIT);

    VaultLogic.erc20IncreaseBorrow(groupData, msg.sender, params.amount);

    VaultLogic.erc20TransferOut(params.asset, msg.sender, params.amount);

    InterestLogic.updateInterestRates(poolData, params.asset, assetData, 0, params.amount);

    emit Events.BorrowERC20ForYield(msg.sender, params.poolId, params.asset, params.amount);
  }

  /**
   * @notice Implements the repay for yield feature.
   * It transfers the underlying back to the pool and clears the equivalent amount of debt.
   */
  function executeRepayERC20ForYield(InputTypes.ExecuteRepayERC20ForYieldParams memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroupId];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateRepayERC20ForYield(params, poolData, assetData, groupData);

    uint256 debtAmount = VaultLogic.erc20GetUserBorrowInGroup(groupData, msg.sender);
    if (debtAmount < params.amount) {
      params.amount = debtAmount;
    }

    VaultLogic.erc20DecreaseBorrow(groupData, msg.sender, params.amount);

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    InterestLogic.updateInterestRates(poolData, params.asset, assetData, 0, params.amount);

    emit Events.RepayERC20ForYield(msg.sender, params.poolId, params.asset, params.amount);
  }
}
