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
import {Configurator} from 'src/modules/Configurator.sol';
import {BVault} from 'src/modules/BVault.sol';
import {CrossLending} from 'src/modules/CrossLending.sol';
import {CrossLiquidation} from 'src/modules/CrossLiquidation.sol';
import {IsolateLending} from 'src/modules/IsolateLending.sol';
import {IsolateLiquidation} from 'src/modules/IsolateLiquidation.sol';
import {Yield} from 'src/modules/Yield.sol';
import {FlashLoan} from 'src/modules/FlashLoan.sol';
import {PoolLens} from 'src/modules/PoolLens.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';

import '@forge-std/Script.sol';

abstract contract DeployBase is Script, Configured {
  using ConfigLib for Config;
  address internal deployer;
  bytes32 internal gitCommitHash;
  string internal etherscanKey;

  function run() external {
    _initConfig();

    _loadConfig();

    deployer = vm.addr(vm.envUint('PRIVATE_KEY'));

    gitCommitHash = vm.envBytes32('GIT_COMMIT_HASH');

    etherscanKey = vm.envString('ETHERSCAN_KEY');

    vm.startBroadcast(deployer);

    _deploy();

    vm.stopBroadcast();
  }

  function _deploy() internal virtual {}

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

  function _deployPoolManager(address addressProvider_) internal returns (address) {
    address addressInCfg = config.getPoolManager();
    require(addressInCfg == address(0), 'PoolManager exist in config');

    // Installer & PoolManager
    Installer tsModInstallerImpl = new Installer(gitCommitHash);
    PoolManager poolManager = new PoolManager(address(addressProvider_), address(tsModInstallerImpl));

    AddressProvider(addressProvider_).setPoolManager(address(poolManager));

    Installer installer = Installer(poolManager.moduleIdToProxy(Constants.MODULEID__INSTALLER));

    // Modules
    address[] memory modules = new address[](9);
    uint modIdx = 0;

    Configurator tsConfiguratorImpl = new Configurator(gitCommitHash);
    modules[modIdx++] = address(tsConfiguratorImpl);

    BVault tsVaultImpl = new BVault(gitCommitHash);
    modules[modIdx++] = address(tsVaultImpl);

    CrossLending tsCrossLendingImpl = new CrossLending(gitCommitHash);
    modules[modIdx++] = address(tsCrossLendingImpl);

    CrossLiquidation tsCrossLiquidationImpl = new CrossLiquidation(gitCommitHash);
    modules[modIdx++] = address(tsCrossLiquidationImpl);

    IsolateLending tsIsolateLendingImpl = new IsolateLending(gitCommitHash);
    modules[modIdx++] = address(tsIsolateLendingImpl);

    IsolateLiquidation tsIsolateLiquidationImpl = new IsolateLiquidation(gitCommitHash);
    modules[modIdx++] = address(tsIsolateLiquidationImpl);

    Yield tsYieldImpl = new Yield(gitCommitHash);
    modules[modIdx++] = address(tsYieldImpl);

    FlashLoan tsFlashLoanImpl = new FlashLoan(gitCommitHash);
    modules[modIdx++] = address(tsFlashLoanImpl);

    PoolLens tsPoolLensImpl = new PoolLens(gitCommitHash);
    modules[modIdx++] = address(tsPoolLensImpl);

    installer.installModules(modules);

    return address(poolManager);
  }
}
