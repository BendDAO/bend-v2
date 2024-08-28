// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BaseModule} from 'src/base/BaseModule.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

import {StorageSlot} from 'src/libraries/logic/StorageSlot.sol';
import {ConfigureLogic} from 'src/libraries/logic/ConfigureLogic.sol';
import {PoolLogic} from 'src/libraries/logic/PoolLogic.sol';

/// @notice ConfiguratorPool Service Logic
contract ConfiguratorPool is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__CONFIGURATOR_POOL, moduleGitCommit_) {}

  /**
   * @dev Pauses or unpauses the whole protocol.
   */
  function setGlobalPause(bool paused) public {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    PoolLogic.checkCallerIsEmergencyAdmin(ps, msgSender);

    if (paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  function getGlobalPause() public view returns (bool) {
    return paused();
  }

  function createPool(string memory name) public nonReentrant returns (uint32 poolId) {
    address msgSender = unpackTrailingParamMsgSender();
    return ConfigureLogic.executeCreatePool(msgSender, name);
  }

  function deletePool(uint32 poolId) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeDeletePool(msgSender, poolId);
  }

  function setPoolName(uint32 poolId, string calldata name) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetPoolName(msgSender, poolId, name);
  }

  function setPoolPause(uint32 poolId, bool paused) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetPoolPause(msgSender, poolId, paused);
  }

  function addPoolGroup(uint32 poolId, uint8 groupId) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    return ConfigureLogic.executeAddPoolGroup(msgSender, poolId, groupId);
  }

  function removePoolGroup(uint32 poolId, uint8 groupId) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeRemovePoolGroup(msgSender, poolId, groupId);
  }

  function setPoolYieldEnable(uint32 poolId, bool isEnable) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetPoolYieldEnable(msgSender, poolId, isEnable);
  }

  function setPoolYieldPause(uint32 poolId, bool isPause) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetPoolYieldPause(msgSender, poolId, isPause);
  }
}
