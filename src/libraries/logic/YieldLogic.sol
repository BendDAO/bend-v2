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

library YieldLogic {
  /**
   * @notice Implements the borrow for yield feature.
   * It allows whitelisted staker to draw liquidity from the protocol without any collateral.
   */
  function executeYieldBorrowERC20(InputTypes.ExecuteYieldBorrowERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroup];
    DataTypes.StakerData storage stakerData = assetData.stakerLookup[msg.sender];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateYieldBorrowERC20(params, poolData, assetData, groupData);

    uint256 stakerBorrow = VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, msg.sender, groupData.borrowIndex);
    require((stakerBorrow + params.amount) <= stakerData.yieldCap, Errors.YIELD_EXCEED_STAKER_CAP_LIMIT);

    uint256 totalBorrow = VaultLogic.erc20GetTotalCrossBorrowInGroup(groupData, groupData.borrowIndex);
    require((totalBorrow + params.amount) < assetData.yieldCap, Errors.YIELD_EXCEED_ASSET_CAP_LIMIT);

    VaultLogic.erc20IncreaseCrossBorrow(groupData, msg.sender, params.amount);

    InterestLogic.updateInterestRates(poolData, assetData, 0, params.amount);

    VaultLogic.erc20TransferOutLiquidity(assetData, msg.sender, params.amount);

    emit Events.YieldBorrowERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  /**
   * @notice Implements the repay for yield feature.
   * It transfers the underlying back to the pool and clears the equivalent amount of debt.
   */
  function executeYieldRepayERC20(InputTypes.ExecuteYieldRepayERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroup];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateYieldRepayERC20(params, poolData, assetData, groupData);

    uint256 debtAmount = VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, msg.sender, groupData.borrowIndex);
    require(debtAmount > 0, Errors.BORROW_BALANCE_IS_ZERO);

    if (debtAmount < params.amount) {
      params.amount = debtAmount;
    }

    VaultLogic.erc20DecreaseCrossBorrow(groupData, msg.sender, params.amount);

    InterestLogic.updateInterestRates(poolData, assetData, params.amount, 0);

    VaultLogic.erc20TransferInLiquidity(assetData, msg.sender, params.amount);

    emit Events.YieldRepayERC20(msg.sender, params.poolId, params.asset, params.amount);
  }
}
