// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import {ACLManager} from 'src/ACLManager.sol';
import {PriceOracle} from 'src/PriceOracle.sol';
import {PoolManager} from 'src/PoolManager.sol';
import {YieldEthStaking} from 'src/YieldEthStaking.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';

import '@forge-std/Script.sol';

contract Deploy is Script, Configured {
  using ConfigLib for Config;
  address internal deployer;
  ACLManager internal aclManager;
  PriceOracle internal priceOracle;
  PoolManager internal poolManager;
  YieldEthStaking internal yieldEthStaking;

  function run() external {
    _initConfig();

    _loadConfig();

    deployer = vm.addr(vm.envUint('PRIVATE_KEY'));

    vm.startBroadcast(deployer);

    _deploy();

    vm.stopBroadcast();
  }

  function _network() internal pure virtual override returns (string memory) {
    return 'eth-sepolia';
  }

  function _deploy() internal {
    address aclAdmin = config.getACLAdmin();
    address treasury = config.getTreasury();

    console.log('aclAdmin:', aclAdmin, 'treasury:', treasury);

    /// Deploy proxies ///
    ProxyAdmin proxyAdmin = new ProxyAdmin();

    /// ACL Manager
    ACLManager aclManagerImpl = new ACLManager();
    TransparentUpgradeableProxy aclManagerProxy = new TransparentUpgradeableProxy(
      address(aclManagerImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(aclManagerImpl.initialize.selector, aclAdmin)
    );
    aclManager = ACLManager(address(aclManagerProxy));

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

    // Pool Manager
    PoolManager poolManagerImpl = new PoolManager();
    TransparentUpgradeableProxy poolManagerProxy = new TransparentUpgradeableProxy(
      address(poolManagerImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(
        poolManagerImpl.initialize.selector,
        address(wNative),
        address(aclManager),
        address(priceOracle),
        treasury
      )
    );
    poolManager = PoolManager(payable(poolManagerProxy));

    // YieldEthStaking
    YieldEthStaking yieldEthStakingImpl = new YieldEthStaking();
    TransparentUpgradeableProxy yieldEthStakingProxy = new TransparentUpgradeableProxy(
      address(yieldEthStakingImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(
        yieldEthStakingImpl.initialize.selector,
        address(poolManager),
        address(weth),
        address(stETH),
        address(unstETH)
      )
    );
    yieldEthStaking = YieldEthStaking(payable(yieldEthStakingProxy));
  }
}
