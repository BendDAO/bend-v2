// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {QueryBase} from './QueryBase.s.sol';

import {PoolManager} from 'src/PoolManager.sol';
import {PoolLens} from 'src/modules/PoolLens.sol';

import '@forge-std/Script.sol';

interface IYieldStakingBase {
  function underlyingAsset() external view returns (address);
}

contract QueryPool is QueryBase {
  using ConfigLib for Config;

  PoolManager poolManager;
  PoolLens poolLens;

  function _query() internal virtual override {
    address addressInCfg = config.getPoolManager();
    require(addressInCfg != address(0), 'PoolManager not exist in config');

    poolManager = PoolManager(payable(addressInCfg));
    poolLens = PoolLens(poolManager.moduleIdToProxy(Constants.MODULEID__POOL_LENS));

    queryUserData(0x8b04B42962BeCb429a4dBFb5025b66D3d7D31d27, 1);

    // queryStakerData(address(0), 1);

    // queryStakerData(0x59303f797B8Dd80fc3743047df63C76E44Ca7CBd, 1);
    // queryStakerData(0x3234F1047E71421Ec67A576D87eaEe1B86E8A1Ea, 1);
    // queryStakerData(0x7464a51fA6338A34b694b4bF4A152781fb2C4B70, 1);
  }

  function queryUserData(address user, uint32 pool) internal view {
    (address[] memory assets /*uint8[] memory types*/, ) = poolLens.getPoolAssetList(pool);

    poolLens.getUserAssetList(user, pool);

    poolLens.getUserAccountData(user, pool);

    poolLens.getUserAccountGroupData(user, pool);

    for (uint i = 0; i < assets.length; i++) {
      poolLens.getUserAssetScaledData(user, pool, assets[i]);
    }
  }

  function queryStakerData(address staker, uint32 pool) internal view {
    if (staker == address(0)) {
      (address[] memory assets, uint8[] memory types) = poolLens.getPoolAssetList(pool);

      for (uint i = 0; i < assets.length; i++) {
        if (types[i] != Constants.ASSET_TYPE_ERC20) {
          continue;
        }
        poolLens.getYieldStakerAssetData(pool, assets[i], staker);
      }
    } else {
      address asset = IYieldStakingBase(staker).underlyingAsset();
      poolLens.getYieldStakerAssetData(pool, asset, staker);
    }
  }
}
