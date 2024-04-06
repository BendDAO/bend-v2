// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {Errors} from 'src/libraries/helpers/Errors.sol';
import {StorageSlot} from 'src/libraries/logic/StorageSlot.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {Base} from 'src/base/Base.sol';

/// @notice Main storage contract
contract PoolManager is Base {
  string public constant name = 'Bend Protocol V2';

  constructor(address provider_, address installerModule) {
    reentrancyLock = Constants.REENTRANCYLOCK__UNLOCKED;

    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    ps.addressProvider = provider_;
    ps.nextPoolId = Constants.INITIAL_POOL_ID;

    ps.wrappedNativeToken = IAddressProvider(ps.addressProvider).getWrappedNativeToken();
    require(ps.wrappedNativeToken != address(0), Errors.INVALID_ADDRESS);

    moduleLookup[Constants.MODULEID__INSTALLER] = installerModule;
    address installerProxy = _createProxy(Constants.MODULEID__INSTALLER);
    trustedSenders[installerProxy].moduleImpl = installerModule;
  }

  /// @notice Lookup the current implementation contract for a module
  /// @param moduleId Fixed constant that refers to a module type
  /// @return An internal address specifies the module's implementation code
  function moduleIdToImplementation(uint moduleId) external view returns (address) {
    return moduleLookup[moduleId];
  }

  /// @notice Lookup a proxy that can be used to interact with a module (only valid for single-proxy modules)
  /// @param moduleId Fixed constant that refers to a module type
  /// @return An address that should be cast to the appropriate module interface
  function moduleIdToProxy(uint moduleId) external view returns (address) {
    return proxyLookup[moduleId];
  }

  function dispatch() external payable reentrantOK {
    uint32 moduleId = trustedSenders[msg.sender].moduleId;
    address moduleImpl = trustedSenders[msg.sender].moduleImpl;

    require(moduleId != 0, 'e/sender-not-trusted');

    if (moduleImpl == address(0)) moduleImpl = moduleLookup[moduleId];

    uint msgDataLength = msg.data.length;
    require(msgDataLength >= (4 + 4 + 20), 'e/input-too-short');

    assembly {
      let payloadSize := sub(calldatasize(), 4)
      calldatacopy(0, 4, payloadSize)
      mstore(payloadSize, shl(96, caller()))

      let result := delegatecall(gas(), moduleImpl, 0, add(payloadSize, 20), 0, 0)

      returndatacopy(0, 0, returndatasize())

      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  receive() external payable {}
}
