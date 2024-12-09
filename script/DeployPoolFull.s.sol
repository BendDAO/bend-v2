// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {AddressProvider} from 'src/AddressProvider.sol';
import {ACLManager} from 'src/ACLManager.sol';
import {PriceOracle} from 'src/PriceOracle.sol';

import {PoolManager} from 'src/PoolManager.sol';
import {Installer} from 'src/modules/Installer.sol';
import {ConfiguratorPool} from 'src/modules/ConfiguratorPool.sol';
import {Configurator} from 'src/modules/Configurator.sol';
import {BVault} from 'src/modules/BVault.sol';
import {CrossLending} from 'src/modules/CrossLending.sol';
import {CrossLiquidation} from 'src/modules/CrossLiquidation.sol';
import {IsolateLending} from 'src/modules/IsolateLending.sol';
import {IsolateLiquidation} from 'src/modules/IsolateLiquidation.sol';
import {Yield} from 'src/modules/Yield.sol';
import {FlashLoan} from 'src/modules/FlashLoan.sol';
import {PoolLens} from 'src/modules/PoolLens.sol';
import {UIPoolLens} from 'src/modules/UIPoolLens.sol';

import {DefaultInterestRateModel} from 'src/irm/DefaultInterestRateModel.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract DeployPoolFull is DeployBase {
  using ConfigLib for Config;

  function _deploy() internal virtual override {
    // _deployPoolFull();

    _deployPoolPart();
  }

  function _deployPoolPart() internal {
    address proxyAdmin_ = config.getProxyAdmin();
    require(proxyAdmin_ != address(0), 'ProxyAdmin not exist in config');

    address addressProvider_ = config.getAddressProvider();
    require(addressProvider_ != address(0), 'AddressProvider not exist in config');

    address defaultIrm_ = _deployDefaultIRM(proxyAdmin_, addressProvider_);
    console.log('DefaultIrm:', defaultIrm_);
  }

  function _deployPoolFull() internal {
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

    address defaultIrm_ = _deployDefaultIRM(proxyAdmin_, addressProvider_);
    console.log('DefaultIrm:', defaultIrm_);
  }

  function _deployProxyAdmin() internal returns (address) {
    address addressInCfg = config.getProxyAdmin();
    require(addressInCfg == address(0), 'ProxyAdmin exist in config');

    ProxyAdmin proxyAdmin = new ProxyAdmin();
    return address(proxyAdmin);
  }

  function _deployAddressProvider(address proxyAdmin_) internal returns (address) {
    address addressInCfg = config.getAddressProvider();
    require(addressInCfg == address(0), 'AddressProvider exist in config');

    AddressProvider addressProviderImpl = new AddressProvider();
    TransparentUpgradeableProxy addressProviderProxy = new TransparentUpgradeableProxy(
      address(addressProviderImpl),
      address(proxyAdmin_),
      abi.encodeWithSelector(addressProviderImpl.initialize.selector)
    );
    AddressProvider addressProvider = AddressProvider(address(addressProviderProxy));

    require(cfgWrappedNative != address(0), 'Invalid WrappedNative in config');
    addressProvider.setWrappedNativeToken(cfgWrappedNative);

    address aclAdmin = config.getACLAdmin();
    require(aclAdmin != address(0), 'Invalid ACLAdmin in config');
    addressProvider.setACLAdmin(aclAdmin);

    address treasury = config.getTreasury();
    require(addressInCfg == address(0), 'Invalid Treasury in config');
    addressProvider.setTreasury(treasury);

    return address(addressProvider);
  }

  function _deployACLManager(address proxyAdmin_, address addressProvider_) internal returns (address) {
    address addressInCfg = config.getACLManager();
    require(addressInCfg == address(0), 'ACLManager exist in config');

    address aclAdmin = config.getACLAdmin();
    require(aclAdmin != address(0), 'Invalid ACLAdmin in config');

    ACLManager aclManagerImpl = new ACLManager();
    TransparentUpgradeableProxy aclManagerProxy = new TransparentUpgradeableProxy(
      address(aclManagerImpl),
      address(proxyAdmin_),
      abi.encodeWithSelector(aclManagerImpl.initialize.selector, aclAdmin)
    );
    ACLManager aclManager = ACLManager(address(aclManagerProxy));

    aclManager.addPoolAdmin(deployer);
    aclManager.addEmergencyAdmin(deployer);
    aclManager.addOracleAdmin(deployer);

    AddressProvider(addressProvider_).setACLManager(address(aclManager));

    return address(aclManager);
  }

  function _deployPriceOracle(address proxyAdmin_, address addressProvider_) internal returns (address) {
    address addressInCfg = config.getPriceOracle();
    require(addressInCfg == address(0), 'PriceOracle exist in config');

    PriceOracle priceOracleImpl = new PriceOracle();
    TransparentUpgradeableProxy priceOracleProxy = new TransparentUpgradeableProxy(
      address(priceOracleImpl),
      address(proxyAdmin_),
      abi.encodeWithSelector(
        priceOracleImpl.initialize.selector,
        address(addressProvider_),
        address(0),
        1e8,
        address(cfgWrappedNative),
        1e18
      )
    );
    PriceOracle priceOracle = PriceOracle(address(priceOracleProxy));

    AddressProvider(addressProvider_).setPriceOracle(address(priceOracle));

    return address(priceOracle);
  }

  function _deployDefaultIRM(address proxyAdmin_, address addressProvider_) internal returns (address) {
    DefaultInterestRateModel defaultIrmImpl = new DefaultInterestRateModel();
    TransparentUpgradeableProxy defaultIrmProxy = new TransparentUpgradeableProxy(
      address(defaultIrmImpl),
      address(proxyAdmin_),
      abi.encodeWithSelector(defaultIrmImpl.initialize.selector, address(addressProvider_))
    );
    DefaultInterestRateModel defaultIrm = DefaultInterestRateModel(address(defaultIrmProxy));

    return address(defaultIrm);
  }

  struct DeployLocalVars {
    address addressInCfg;
    address[] modules;
    uint modIdx;
    PoolManager poolManager;
    Installer tsModInstallerImpl;
    Installer installer;
    ConfiguratorPool tsConfiguratorPoolImpl;
    Configurator tsConfiguratorImpl;
    BVault tsVaultImpl;
    CrossLending tsCrossLendingImpl;
    CrossLiquidation tsCrossLiquidationImpl;
    IsolateLending tsIsolateLendingImpl;
    IsolateLiquidation tsIsolateLiquidationImpl;
    Yield tsYieldImpl;
    FlashLoan tsFlashLoanImpl;
    PoolLens tsPoolLensImpl;
    UIPoolLens tsUIPoolLensImpl;
  }

  function _deployPoolManager(address addressProvider_) internal returns (address) {
    DeployLocalVars memory vars;

    vars.addressInCfg = config.getPoolManager();
    require(vars.addressInCfg == address(0), 'PoolManager exist in config');

    // Installer & PoolManager
    vars.tsModInstallerImpl = new Installer(gitCommitHash);
    vars.poolManager = new PoolManager(address(addressProvider_), address(vars.tsModInstallerImpl));

    AddressProvider(addressProvider_).setPoolManager(address(vars.poolManager));

    vars.installer = Installer(vars.poolManager.moduleIdToProxy(Constants.MODULEID__INSTALLER));

    // Modules
    vars.modules = new address[](11);
    vars.modIdx = 0;

    vars.tsConfiguratorPoolImpl = new ConfiguratorPool(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsConfiguratorPoolImpl);

    vars.tsConfiguratorImpl = new Configurator(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsConfiguratorImpl);

    vars.tsVaultImpl = new BVault(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsVaultImpl);

    vars.tsCrossLendingImpl = new CrossLending(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsCrossLendingImpl);

    vars.tsCrossLiquidationImpl = new CrossLiquidation(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsCrossLiquidationImpl);

    vars.tsIsolateLendingImpl = new IsolateLending(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsIsolateLendingImpl);

    vars.tsIsolateLiquidationImpl = new IsolateLiquidation(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsIsolateLiquidationImpl);

    vars.tsYieldImpl = new Yield(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsYieldImpl);

    vars.tsFlashLoanImpl = new FlashLoan(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsFlashLoanImpl);

    vars.tsPoolLensImpl = new PoolLens(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsPoolLensImpl);

    vars.tsUIPoolLensImpl = new UIPoolLens(gitCommitHash);
    vars.modules[vars.modIdx++] = address(vars.tsUIPoolLensImpl);

    vars.installer.installModules(vars.modules);

    return address(vars.poolManager);
  }
}
