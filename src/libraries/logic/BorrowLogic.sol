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
  function executeCrossBorrowERC20(InputTypes.ExecuteCrossBorrowERC20Params memory params) public {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    // check the basic params
    ValidateLogic.validateBorrowERC20Basic(params, poolData, assetData);

    // account status need latest balance, update supply & borrow index first
    InterestLogic.updateInterestSupplyIndex(assetData);

    for (uint256 gidx = 0; gidx < params.groups.length; gidx++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[params.groups[gidx]];

      InterestLogic.updateInterestBorrowIndex(assetData, groupData);
    }

    // check the user account
    ValidateLogic.validateBorrowERC20Account(params, poolData, assetData, msg.sender, cs.priceOracle);

    // update debt state
    uint256 totalBorrowAmount;
    for (uint256 gidx = 0; gidx < params.groups.length; gidx++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[params.groups[gidx]];

      VaultLogic.erc20IncreaseBorrow(groupData, msg.sender, params.amounts[gidx]);
      totalBorrowAmount += params.amounts[gidx];
    }

    VaultLogic.accountCheckAndSetBorrowedAsset(poolData, assetData, msg.sender);

    InterestLogic.updateInterestRates(poolData, assetData, 0, totalBorrowAmount);

    // transfer underlying asset to borrower
    VaultLogic.erc20TransferOut(params.asset, msg.sender, totalBorrowAmount);

    emit Events.CrossBorrowERC20(msg.sender, params.poolId, params.asset, params.groups, params.amounts);
  }

  function executeCrossRepayERC20(InputTypes.ExecuteCrossRepayERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    // do some basic checks, e.g. params
    ValidateLogic.validateRepayERC20Basic(params, poolData, assetData);

    // account status need latest balance, update supply & borrow index first
    InterestLogic.updateInterestSupplyIndex(assetData);

    for (uint256 gidx = 0; gidx < params.groups.length; gidx++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[params.groups[gidx]];

      InterestLogic.updateInterestBorrowIndex(assetData, groupData);
    }

    // update debt state
    uint256 totalRepayAmount;
    for (uint256 gidx = 0; gidx < params.groups.length; gidx++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[params.groups[gidx]];

      uint256 debtAmount = VaultLogic.erc20GetUserBorrowInGroup(groupData, msg.sender);
      require(debtAmount > 0, Errors.BORROW_BALANCE_IS_ZERO);

      if (debtAmount < params.amounts[gidx]) {
        params.amounts[gidx] = debtAmount;
      }

      VaultLogic.erc20DecreaseBorrow(groupData, msg.sender, params.amounts[gidx]);

      totalRepayAmount += params.amounts[gidx];
    }

    VaultLogic.accountCheckAndSetBorrowedAsset(poolData, assetData, msg.sender);

    InterestLogic.updateInterestRates(poolData, assetData, totalRepayAmount, 0);

    // transfer underlying asset from borrower to pool
    VaultLogic.erc20TransferIn(params.asset, msg.sender, totalRepayAmount);

    emit Events.CrossRepayERC20(msg.sender, params.poolId, params.asset, params.groups, params.amounts);
  }

  /**
   * @notice Implements the borrow for yield feature.
   * It allows whitelisted staker to draw liquidity from the protocol without any collateral.
   */
  function executeYieldBorrowERC20(InputTypes.ExecuteYieldBorrowERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroupId];
    DataTypes.StakerData storage stakerData = assetData.stakerLookup[params.staker];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateYieldBorrowERC20(params, poolData, assetData, groupData);

    uint256 debtAmount = VaultLogic.erc20GetUserBorrowInGroup(groupData, msg.sender);
    require((debtAmount + params.amount) <= stakerData.yieldCap, Errors.YIELD_EXCEED_CAP_LIMIT);

    VaultLogic.erc20IncreaseBorrow(groupData, msg.sender, params.amount);

    InterestLogic.updateInterestRates(poolData, assetData, 0, params.amount);

    VaultLogic.erc20TransferOut(params.asset, msg.sender, params.amount);

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
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroupId];

    InterestLogic.updateInterestIndexs(assetData, groupData);

    ValidateLogic.validateYieldRepayERC20(params, poolData, assetData, groupData);

    uint256 debtAmount = VaultLogic.erc20GetUserBorrowInGroup(groupData, msg.sender);
    require(debtAmount > 0, Errors.BORROW_BALANCE_IS_ZERO);

    if (debtAmount < params.amount) {
      params.amount = debtAmount;
    }

    VaultLogic.erc20DecreaseBorrow(groupData, msg.sender, params.amount);

    InterestLogic.updateInterestRates(poolData, assetData, params.amount, 0);

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    emit Events.YieldRepayERC20(msg.sender, params.poolId, params.asset, params.amount);
  }
}
