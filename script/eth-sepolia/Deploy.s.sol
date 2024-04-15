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

contract Deploy is Script, Configured {
  using ConfigLib for Config;
  address internal deployer;
  bytes32 internal gitCommitHash;
  AddressProvider internal addressProvider;
  ACLManager internal aclManager;
  PriceOracle internal priceOracle;
  PoolManager internal poolManager;

  function run() external {
    _initConfig();

    _loadConfig();

    deployer = vm.addr(vm.envUint('PRIVATE_KEY'));

    gitCommitHash = vm.envBytes32('GIT_COMMIT_HASH');

    vm.startBroadcast(deployer);

    _deploy();

    vm.stopBroadcast();
  }

  function _network() internal pure virtual override returns (string memory) {
    return 'eth-sepolia';
  }

  function _deploy() internal {
    address aclAdmin = deployer; // config.getACLAdmin();
    address treasury = config.getTreasury();

    console.log('aclAdmin:', aclAdmin, 'treasury:', treasury);

    /// Deploy proxies ///
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    /// Address Provider
    AddressProvider addressProviderImpl = new AddressProvider();
    TransparentUpgradeableProxy addressProviderProxy = new TransparentUpgradeableProxy(
      address(addressProviderImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(addressProviderImpl.initialize.selector)
    );
    addressProvider = AddressProvider(address(addressProviderProxy));
    addressProvider.setWrappedNativeToken(address(wNative));
    addressProvider.setTreasury(treasury);
    addressProvider.setACLAdmin(aclAdmin);

    /// ACL Manager
    ACLManager aclManagerImpl = new ACLManager();
    TransparentUpgradeableProxy aclManagerProxy = new TransparentUpgradeableProxy(
      address(aclManagerImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(aclManagerImpl.initialize.selector, aclAdmin)
    );
    aclManager = ACLManager(address(aclManagerProxy));
    aclManager.addPoolAdmin(deployer);
    addressProvider.setACLManager(address(aclManager));

    /// Price Oracle
    PriceOracle priceOracleImpl = new PriceOracle();
    TransparentUpgradeableProxy priceOracleProxy = new TransparentUpgradeableProxy(
      address(priceOracleImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(
        priceOracleImpl.initialize.selector,
        address(aclManager),
        address(0),
        1e8,
        address(wNative),
        1e18
      )
    );
    priceOracle = PriceOracle(address(priceOracleProxy));
    addressProvider.setPriceOracle(address(priceOracle));

    // Pool Manager
    Installer tsModInstallerImpl = new Installer(gitCommitHash);
    poolManager = new PoolManager(address(addressProvider), address(tsModInstallerImpl));
    addressProvider.setPoolManager(address(poolManager));

    Installer installer = Installer(poolManager.moduleIdToProxy(Constants.MODULEID__INSTALLER));

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
  }
}
