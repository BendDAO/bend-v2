// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ITransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';

import {AddressProvider} from 'src/AddressProvider.sol';
import {PriceOracle} from 'src/PriceOracle.sol';

import {YieldRegistry} from 'src/yield/YieldRegistry.sol';
import {YieldEthStakingLido} from 'src/yield/lido/YieldEthStakingLido.sol';
import {YieldEthStakingEtherfi} from 'src/yield/etherfi/YieldEthStakingEtherfi.sol';
import {YieldSavingsDai} from 'src/yield/sdai/YieldSavingsDai.sol';

import {BendV1Migration} from 'src/migrations/BendV1Migration.sol';

import '@forge-std/Script.sol';

contract UpgradeContract is DeployBase {
  using ConfigLib for Config;

  address internal addrYieldLido;
  address internal addrYieldEtherfi;
  address internal addrYieldSDai;
  address internal addrBendV1Migration;

  function _deploy() internal virtual override {
    if (block.chainid == 1) {
      addrYieldLido = 0x61Ae6DCE4C7Cb1b8165aE244c734f20DF56efd73;
      addrYieldEtherfi = 0x529a8822416c3c4ED1B77dE570118fDf1d474639;
      addrYieldSDai = 0x6FA43C1a296db746937Ac4D97Ff61409E8c530cC;
      addrBendV1Migration = 0xf6EE27bb3F17E456078711D8c4b257377375D654;
    } else if (block.chainid == 11155111) {
      addrYieldLido = 0x59303f797B8Dd80fc3743047df63C76E44Ca7CBd;
      addrYieldEtherfi = 0x3234F1047E71421Ec67A576D87eaEe1B86E8A1Ea;
      addrYieldSDai = 0x7464a51fA6338A34b694b4bF4A152781fb2C4B70;
      addrBendV1Migration = 0x989c290B431DA780C3Fce9640488E7967C1bAB84;
    } else {
      revert('chainid not support');
    }

    address proxyAdminInCfg = config.getProxyAdmin();
    require(proxyAdminInCfg != address(0), 'ProxyAdmin not exist in config');

    address addrProviderInCfg = config.getAddressProvider();
    require(addrProviderInCfg != address(0), 'AddressProvider not exist in config');

    //_upgradeAddressProvider(proxyAdminInCfg, addrProviderInCfg);
    //_upgradePriceOracle(proxyAdminInCfg, addrProviderInCfg);

    //_upgradeYieldRegistry(proxyAdminInCfg, addrProviderInCfg);

    _upgradeYieldEthStakingLido(proxyAdminInCfg, addrProviderInCfg);
    _upgradeYieldEthStakingEtherfi(proxyAdminInCfg, addrProviderInCfg);
    _upgradeYieldSavingsDai(proxyAdminInCfg, addrProviderInCfg);

    //_upgradeBendV1Migration(proxyAdminInCfg, addrProviderInCfg);
  }

  function _upgradeAddressProvider(address proxyAdmin_, address addressProvider_) internal {
    AddressProvider newImpl = new AddressProvider();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(addressProvider_), address(newImpl));
  }

  function _upgradePriceOracle(address proxyAdmin_, address addressProvider_) internal {
    address proxyAddr_ = AddressProvider(addressProvider_).getPriceOracle();
    PriceOracle newImpl = new PriceOracle();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddr_), address(newImpl));
  }

  function _upgradeYieldRegistry(address proxyAdmin_, address addressProvider_) internal {
    address proxyAddr_ = AddressProvider(addressProvider_).getYieldRegistry();
    YieldRegistry newImpl = new YieldRegistry();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddr_), address(newImpl));
  }

  function _upgradeYieldEthStakingLido(address proxyAdmin_, address /*addressProvider_*/) internal {
    YieldEthStakingLido newImpl = new YieldEthStakingLido();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(addrYieldLido), address(newImpl));
  }

  function _upgradeYieldEthStakingEtherfi(address proxyAdmin_, address /*addressProvider_*/) internal {
    YieldEthStakingEtherfi newImpl = new YieldEthStakingEtherfi();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(addrYieldEtherfi), address(newImpl));
  }

  function _upgradeYieldSavingsDai(address proxyAdmin_, address /*addressProvider_*/) internal {
    YieldSavingsDai newImpl = new YieldSavingsDai();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(addrYieldSDai), address(newImpl));
  }

  function _upgradeBendV1Migration(address proxyAdmin_, address /*addressProvider_*/) internal {
    BendV1Migration newImpl = new BendV1Migration();

    ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdmin_);
    proxyAdmin.upgrade(ITransparentUpgradeableProxy(addrBendV1Migration), address(newImpl));
  }
}
