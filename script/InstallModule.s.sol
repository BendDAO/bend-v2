// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';

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
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract InstallModule is DeployBase {
  using ConfigLib for Config;

  function _deploy() internal virtual override {
    address addressInCfg = config.getPoolManager();
    require(addressInCfg != address(0), 'PoolManager not exist in config');

    PoolManager poolManager = PoolManager(payable(addressInCfg));

    Installer installer = Installer(poolManager.moduleIdToProxy(Constants.MODULEID__INSTALLER));

    address[] memory modules = new address[](2);
    uint modIdx = 0;

    BVault tsVaultImpl = new BVault(gitCommitHash);
    modules[modIdx++] = address(tsVaultImpl);

    CrossLiquidation tsCrossLiquidationImpl = new CrossLiquidation(gitCommitHash);
    modules[modIdx++] = address(tsCrossLiquidationImpl);

    installer.installModules(modules);
  }
}
