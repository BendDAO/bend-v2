// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {PercentageMath} from '../math/PercentageMath.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';
import {ValidateLogic} from './ValidateLogic.sol';

import 'forge-std/console.sol';

library YieldLogic {
  using PercentageMath for uint256;

  struct ExecuteYieldBorrowERC20LocalVars {
    address stakerAddr;
    uint256 stakerBorrow;
    uint256 totalSupply;
    uint256 totalBorrow;
  }

  /**
   * @notice Implements the borrow for yield feature.
   * It allows whitelisted staker to draw liquidity from the protocol without any collateral.
   */
  function executeYieldBorrowERC20(InputTypes.ExecuteYieldBorrowERC20Params memory params) public {
    ExecuteYieldBorrowERC20LocalVars memory vars;
    if (params.isExternalCaller) {
      vars.stakerAddr = msg.sender;
    } else {
      vars.stakerAddr = address(this);
    }

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroup];
    DataTypes.StakerData storage stakerData = assetData.stakerLookup[vars.stakerAddr];

    InterestLogic.updateInterestIndexs(poolData, assetData);

    ValidateLogic.validateYieldBorrowERC20(params, poolData, assetData, groupData);

    vars.totalSupply = VaultLogic.erc20GetTotalCrossSupply(assetData, groupData.borrowIndex);

    // check asset level yield cap limit
    vars.totalBorrow = VaultLogic.erc20GetTotalCrossBorrowInGroup(groupData, groupData.borrowIndex);
    require(
      (vars.totalBorrow + params.amount) <= vars.totalSupply.percentMul(assetData.yieldCap),
      Errors.YIELD_EXCEED_ASSET_CAP_LIMIT
    );

    // check staker level yield cap limit
    vars.stakerBorrow = VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, vars.stakerAddr, groupData.borrowIndex);
    require(
      (vars.stakerBorrow + params.amount) <= vars.totalSupply.percentMul(stakerData.yieldCap),
      Errors.YIELD_EXCEED_STAKER_CAP_LIMIT
    );

    VaultLogic.erc20IncreaseCrossBorrow(groupData, vars.stakerAddr, params.amount);

    InterestLogic.updateInterestRates(poolData, assetData, 0, params.amount);

    VaultLogic.erc20TransferOutLiquidity(assetData, vars.stakerAddr, params.amount);

    emit Events.YieldBorrowERC20(vars.stakerAddr, params.poolId, params.asset, params.amount);
  }

  struct ExecuteYieldRepayERC20LocalVars {
    address stakerAddr;
    uint256 stakerBorrow;
  }

  /**
   * @notice Implements the repay for yield feature.
   * It transfers the underlying back to the pool and clears the equivalent amount of debt.
   */
  function executeYieldRepayERC20(InputTypes.ExecuteYieldRepayERC20Params memory params) public {
    ExecuteYieldRepayERC20LocalVars memory vars;
    if (params.isExternalCaller) {
      vars.stakerAddr = msg.sender;
    } else {
      vars.stakerAddr = address(this);
    }

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroup];

    InterestLogic.updateInterestIndexs(poolData, assetData);

    ValidateLogic.validateYieldRepayERC20(params, poolData, assetData, groupData);

    vars.stakerBorrow = VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, vars.stakerAddr, groupData.borrowIndex);
    require(vars.stakerBorrow > 0, Errors.BORROW_BALANCE_IS_ZERO);

    if (vars.stakerBorrow < params.amount) {
      params.amount = vars.stakerBorrow;
    }

    VaultLogic.erc20DecreaseCrossBorrow(groupData, vars.stakerAddr, params.amount);

    InterestLogic.updateInterestRates(poolData, assetData, params.amount, 0);

    VaultLogic.erc20TransferInLiquidity(assetData, vars.stakerAddr, params.amount);

    emit Events.YieldRepayERC20(vars.stakerAddr, params.poolId, params.asset, params.amount);
  }
}
