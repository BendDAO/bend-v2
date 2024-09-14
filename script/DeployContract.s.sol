// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {BendV1Migration} from 'src/migrations/BendV1Migration.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract DeployContract is DeployBase {
  using ConfigLib for Config;

  function _deploy() internal virtual override {
    address proxyAdminInCfg = config.getProxyAdmin();
    require(proxyAdminInCfg != address(0), 'ProxyAdmin not exist in config');

    address addrProviderInCfg = config.getAddressProvider();
    require(addrProviderInCfg != address(0), 'AddressProvider not exist in config');

    _deployBendV1Migration(proxyAdminInCfg, addrProviderInCfg);
  }

  function _deployBendV1Migration(address proxyAdmin_, address addressProvider_) internal returns (address) {
    address v1AddressProvider = address(0);

    uint256 chainId = config.getChainId();
    if (chainId == 1) {
      // mainnet
      v1AddressProvider = 0x24451F47CaF13B24f4b5034e1dF6c0E401ec0e46;
    } else if (chainId == 11155111) {
      // sepolia
      v1AddressProvider = 0x95e84AED75EB9A545D817c391A0011E0B34EAf5C;
    } else {
      revert('not support');
    }

    BendV1Migration v1MigrationImpl = new BendV1Migration();

    TransparentUpgradeableProxy v1MigrationProxy = new TransparentUpgradeableProxy(
      address(v1MigrationImpl),
      address(proxyAdmin_),
      abi.encodeWithSelector(v1MigrationImpl.initialize.selector, address(addressProvider_), v1AddressProvider)
    );
    BendV1Migration v1Migration = BendV1Migration((address(v1MigrationProxy)));
    console.log('BendV1Migration:', address(v1Migration));

    return address(v1Migration);
  }
}
