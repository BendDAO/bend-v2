// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {SDAIPriceAdapter} from 'src/oracles/SDAIPriceAdapter.sol';
import {EETHPriceAdapter} from 'src/oracles/EETHPriceAdapter.sol';
import {SUSDSPriceAdapter} from 'src/oracles/SUSDSPriceAdapter.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract DeployPriceAdapter is DeployBase {
  using ConfigLib for Config;

  function _deploy() internal virtual override {
    address proxyAdminInCfg = config.getProxyAdmin();
    require(proxyAdminInCfg != address(0), 'ProxyAdmin not exist in config');

    address addrProviderInCfg = config.getAddressProvider();
    require(addrProviderInCfg != address(0), 'AddressProvider not exist in config');

    // _deploySDAIPriceAdapter(proxyAdminInCfg, addrProviderInCfg);

    // _deployEETHPriceAdapter(proxyAdminInCfg, addrProviderInCfg);

    // _deployUSDSPriceAdapter(proxyAdminInCfg, addrProviderInCfg);
  }

  function _deploySDAIPriceAdapter(address /*proxyAdmin_*/, address /*addressProvider_*/) internal returns (address) {
    address daiAgg = address(0);
    address ratePot = address(0);

    uint256 chainId = config.getChainId();
    if (chainId == 1) {
      // mainnet
      daiAgg = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
      ratePot = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;
    } else if (chainId == 11155111) {
      // sepolia
      daiAgg = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
      ratePot = 0x30252a71d6bC66f772b1Ed7d07CdEa2952a0F032;
    } else {
      revert('not support');
    }

    SDAIPriceAdapter sdaiAdapter = new SDAIPriceAdapter(daiAgg, ratePot, 'sDAI / USD');
    console.log('SDAIPriceAdapter:', address(sdaiAdapter));

    return address(sdaiAdapter);
  }

  function _deployEETHPriceAdapter(address /*proxyAdmin_*/, address /*addressProvider_*/) internal returns (address) {
    address ethAggAddress = address(0);
    address weETHAggAddress = address(0);
    address weETHAddress = address(0);

    uint256 chainId = config.getChainId();
    if (chainId == 1) {
      // mainnet
      ethAggAddress = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
      weETHAggAddress = 0x5c9C449BbC9a6075A2c061dF312a35fd1E05fF22;
      weETHAddress = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    } else if (chainId == 11155111) {
      // sepolia
      ethAggAddress = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
      weETHAggAddress = 0x2CFb337f5699c1419AE0dfe2940F628FEF7FC682;
      weETHAddress = 0xb944C510F81553E39F8Db2A89e3f8007A910827f;
    } else {
      revert('not support');
    }

    EETHPriceAdapter eEthAdapter = new EETHPriceAdapter(
      ethAggAddress,
      weETHAggAddress,
      weETHAddress,
      'eETH / weETH / ETH / USD'
    );
    console.log('EETHPriceAdapter:', address(eEthAdapter));

    return address(eEthAdapter);
  }

  function _deployUSDSPriceAdapter(address /*proxyAdmin_*/, address /*addressProvider_*/) internal returns (address) {
    address usdsAgg = address(0);
    address rateProvider = address(0);

    uint256 chainId = config.getChainId();
    if (chainId == 1) {
      // mainnet
      usdsAgg = 0xfF30586cD0F29eD462364C7e81375FC0C71219b1;
      rateProvider = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    } else if (chainId == 11155111) {
      // sepolia
      usdsAgg = 0x7354784A7A705963b484Fed3a903FF8c9b6Ec617;
      rateProvider = 0xf8B05Dab36ea0492E4e358FeF83a608e4297b3D4;
    } else {
      revert('not support');
    }

    SUSDSPriceAdapter susdsAdapter = new SUSDSPriceAdapter(usdsAgg, rateProvider, 'sUSDS / USD');
    console.log('SUSDSPriceAdapter:', address(susdsAdapter));

    return address(susdsAdapter);
  }
}
