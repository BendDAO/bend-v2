// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {QueryBase} from './QueryBase.s.sol';

import {PoolManager} from 'src/PoolManager.sol';
import {PoolLens} from 'src/modules/PoolLens.sol';

import '@forge-std/Script.sol';

contract QueryPool is QueryBase {
  using ConfigLib for Config;

  function _query() internal virtual override {
    address addressInCfg = config.getPoolManager();
    require(addressInCfg != address(0), 'PoolManager not exist in config');

    PoolManager poolManager = PoolManager(payable(addressInCfg));

    PoolLens poolLens = PoolLens(poolManager.moduleIdToProxy(Constants.MODULEID__POOL_LENS));

    poolLens.getUserAssetList(0xc24c9Af9007B8Eb713eFf069CDeC013DD86402E8, 1);

    poolLens.getUserAccountData(0xc24c9Af9007B8Eb713eFf069CDeC013DD86402E8, 1);

    poolLens.getUserAccountGroupData(0xc24c9Af9007B8Eb713eFf069CDeC013DD86402E8, 1);

    poolLens.getUserAssetScaledData(
      0xc24c9Af9007B8Eb713eFf069CDeC013DD86402E8,
      1,
      0xf9a88B0cc31f248c89F063C2928fA10e5A029B88
    );
  }
}
