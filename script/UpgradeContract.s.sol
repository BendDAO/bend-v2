// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ITransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';

import {AddressProvider} from 'src/AddressProvider.sol';

import '@forge-std/Script.sol';

contract UpgradeContract is DeployBase {
  using ConfigLib for Config;

  function _deploy() internal virtual override {
    address proxyAdminInCfg = config.getProxyAdmin();
    require(proxyAdminInCfg != address(0), 'ProxyAdmin not exist in config');

    address addrProviderInCfg = config.getAddressProvider();
    require(addrProviderInCfg != address(0), 'AddressProvider not exist in config');

    _upgradeAddressProvider(proxyAdminInCfg, addrProviderInCfg);
  }

  function _upgradeAddressProvider(address proxyAdmin_, address addressProvider_) internal {
    AddressProvider addressProviderImpl = new AddressProvider();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(addressProvider_), address(addressProviderImpl));
  }
}
