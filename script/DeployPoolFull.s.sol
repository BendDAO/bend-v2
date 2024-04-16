// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract DeployPoolFull is DeployBase {
  using ConfigLib for Config;

  function _deploy() internal virtual override {
    address proxyAdmin_ = _deployProxyAdmin();
    console.log('ProxyAdmin:', proxyAdmin_);

    address addressProvider_ = _deployAddressProvider(proxyAdmin_);
    console.log('AddressProvider:', addressProvider_);

    address aclManager_ = _deployACLManager(proxyAdmin_, addressProvider_);
    console.log('ACLManager:', aclManager_);

    address priceOracle_ = _deployPriceOracle(proxyAdmin_, addressProvider_);
    console.log('PriceOracle:', priceOracle_);

    address poolManager_ = _deployPoolManager(addressProvider_);
    console.log('PoolManager:', poolManager_);
  }
}
