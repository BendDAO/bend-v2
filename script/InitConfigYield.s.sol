// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

import {AddressProvider} from 'src/AddressProvider.sol';
import {PriceOracle} from 'src/PriceOracle.sol';
import {Configurator} from 'src/modules/Configurator.sol';
import {DefaultInterestRateModel} from 'src/irm/DefaultInterestRateModel.sol';

import {YieldEthStakingLido} from 'src/yield/lido/YieldEthStakingLido.sol';
import {YieldEthStakingEtherfi} from 'src/yield/etherfi/YieldEthStakingEtherfi.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract InitConfigYield is DeployBase {
  using ConfigLib for Config;

  address internal addrWETH;
  address internal addrWPUNK;
  address internal addrBAYC;
  address internal addrMAYC;

  address internal addrYieldLido;
  address internal addrYieldEtherfi;
  address internal addrIrmYield;
  uint32 commonPoolId;

  AddressProvider internal addressProvider;
  PriceOracle internal priceOracle;
  Configurator internal configurator;

  function _deploy() internal virtual override {
    if (block.chainid == 11155111) {
      addrWETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
      addrWPUNK = 0x647dc527Bd7dFEE4DD468cE6fC62FC50fa42BD8b;
      addrBAYC = 0xE15A78992dd4a9d6833eA7C9643650d3b0a2eD2B;
      addrMAYC = 0xD0ff8ae7E3D9591605505D3db9C33b96c4809CDC;

      addrYieldLido = 0xbEbd4006710434493Ee223192272c7c7Ed3E8fFE;
      addrYieldEtherfi = 0x337fa37aB2379acbcAD08428cE2eDC2B2212005c;

      commonPoolId = 1;
      addrIrmYield = 0x768B4E53027D266cA391F117Dc81Dd69acdFB638;
    } else {
      revert('chainid not support');
    }

    address addressProvider_ = config.getAddressProvider();
    require(addressProvider_ != address(0), 'Invalid AddressProvider in config');
    addressProvider = AddressProvider(addressProvider_);
    priceOracle = PriceOracle(addressProvider.getPriceOracle());
    configurator = Configurator(addressProvider.getPoolModuleProxy(Constants.MODULEID__CONFIGURATOR));

    initYieldPools();

    initYieldEthStaking();
  }

  function initYieldPools() internal {
    configurator.setPoolYieldEnable(commonPoolId, true);

    IERC20Metadata weth = IERC20Metadata(addrWETH);
    configurator.setAssetYieldEnable(commonPoolId, address(weth), true);
    configurator.setAssetYieldCap(commonPoolId, address(weth), 2000);
    configurator.setAssetYieldRate(commonPoolId, address(weth), address(addrIrmYield));

    configurator.setManagerYieldCap(commonPoolId, address(addrYieldLido), address(addrWETH), 2000);
    configurator.setManagerYieldCap(commonPoolId, address(addrYieldEtherfi), address(addrWETH), 2000);
  }

  function initYieldEthStaking() internal {
    YieldEthStakingLido yieldEthStakingLido = YieldEthStakingLido(payable(addrYieldLido));

    yieldEthStakingLido.setNftActive(address(addrWPUNK), true);
    yieldEthStakingLido.setNftStakeParams(address(addrWPUNK), 50000, 9000);
    yieldEthStakingLido.setNftUnstakeParams(address(addrWPUNK), 100, 1.05e18);

    yieldEthStakingLido.setNftActive(address(addrBAYC), true);
    yieldEthStakingLido.setNftStakeParams(address(addrBAYC), 50000, 9000);
    yieldEthStakingLido.setNftUnstakeParams(address(addrBAYC), 100, 1.05e18);

    YieldEthStakingEtherfi yieldEthStakingEtherfi = YieldEthStakingEtherfi(payable(addrYieldEtherfi));

    yieldEthStakingEtherfi.setNftActive(address(addrWPUNK), true);
    yieldEthStakingEtherfi.setNftStakeParams(address(addrWPUNK), 20000, 9000);
    yieldEthStakingEtherfi.setNftUnstakeParams(address(addrWPUNK), 100, 1.05e18);

    yieldEthStakingEtherfi.setNftActive(address(addrBAYC), true);
    yieldEthStakingEtherfi.setNftStakeParams(address(addrBAYC), 20000, 9000);
    yieldEthStakingEtherfi.setNftUnstakeParams(address(addrBAYC), 100, 1.05e18);
  }
}
