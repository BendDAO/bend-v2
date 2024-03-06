// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import 'config/Configured.sol';

import '@forge-std/Script.sol';

contract Deploy is Script, Configured {
  function run() external {
    _initConfig();
    _loadConfig();

    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    _deploy();

    vm.stopBroadcast();
  }

  function _network() internal pure virtual override returns (string memory) {
    return 'eth-sepolia';
  }

  function _deploy() internal {}
}
