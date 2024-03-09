// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IWETH} from '../../interfaces/IWETH.sol';

library PoolLogic {
  // check caller's permission
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

  // native token
  function wrapNativeToken(DataTypes.PoolStorage storage ps) internal {
    IWETH(ps.wrappedNativeToken).deposit{value: msg.value}();
    IWETH(ps.wrappedNativeToken).transferFrom(address(this), msg.sender, msg.value);
  }

  function unwrapNativeToken(DataTypes.PoolStorage storage ps, uint256 amount) internal {
    IWETH(ps.wrappedNativeToken).transferFrom(msg.sender, address(this), amount);
    IWETH(ps.wrappedNativeToken).withdraw(amount);
  }
}
