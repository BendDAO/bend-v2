// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {IACLManager} from '../../interfaces/IACLManager.sol';

library PoolLogic {
  function checkCallerIsPoolAdmin(DataTypes.PoolStorage storage ps) internal view {
    IACLManager aclManager = IACLManager(ps.aclManager);
    require(aclManager.isPoolAdmin(msg.sender), Errors.CALLER_NOT_POOL_ADMIN);
  }

  function checkCallerIsEmergencyAdmin(DataTypes.PoolStorage storage ps) internal view {
    IACLManager aclManager = IACLManager(ps.aclManager);
    require(aclManager.isEmergencyAdmin(msg.sender), Errors.CALLER_NOT_EMERGENCY_ADMIN);
  }

  function checkCallerIsOracleAdmin(DataTypes.PoolStorage storage ps) internal view {
    IACLManager aclManager = IACLManager(ps.aclManager);
    require(aclManager.isOracleAdmin(msg.sender), Errors.CALLER_NOT_ORACLE_ADMIN);
  }

  function setPoolPause(uint32 poolId, bool paused) public {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    checkCallerIsEmergencyAdmin(ps);

    poolData.isPaused = paused;
    emit Events.SetPoolPause(poolId, paused);
  }
}
