// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

import {AddressProvider} from 'src/AddressProvider.sol';
import {PriceOracle} from 'src/PriceOracle.sol';
import {ConfiguratorPool} from 'src/modules/ConfiguratorPool.sol';
import {Configurator} from 'src/modules/Configurator.sol';
import {DefaultInterestRateModel} from 'src/irm/DefaultInterestRateModel.sol';

import {YieldEthStakingLido} from 'src/yield/lido/YieldEthStakingLido.sol';
import {YieldEthStakingEtherfi} from 'src/yield/etherfi/YieldEthStakingEtherfi.sol';
import {YieldSavingsDai} from 'src/yield/sdai/YieldSavingsDai.sol';

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract InitConfigYield is DeployBase {
  using ConfigLib for Config;

  address internal addrWETH;
  address internal addrDAI;

  address internal addrWPUNK;
  address internal addrBAYC;
  address internal addrStBAYC;
  address internal addrMAYC;
  address internal addrStMAYC;
  address internal addrPPG;
  address internal addrAZUKI;

  address internal addrYieldLido;
  address internal addrYieldEtherfi;
  address internal addrYieldSDai;

  address internal addrIrmYield;
  uint32 commonPoolId;

  AddressProvider internal addressProvider;
  PriceOracle internal priceOracle;
  ConfiguratorPool internal configuratorPool;
  Configurator internal configurator;

  function _deploy() internal virtual override {
    if (block.chainid == 11155111) {
      addrWETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
      addrDAI = 0xf9a88B0cc31f248c89F063C2928fA10e5A029B88;

      addrWPUNK = 0x647dc527Bd7dFEE4DD468cE6fC62FC50fa42BD8b;
      addrBAYC = 0xE15A78992dd4a9d6833eA7C9643650d3b0a2eD2B;
      addrStBAYC = 0x214455B76E5A5dECB48557417397B831efC6219b;
      addrMAYC = 0xD0ff8ae7E3D9591605505D3db9C33b96c4809CDC;
      addrStMAYC = 0xE5165Aae8D50371A277f266eC5A0E00405B532C8;
      addrPPG = 0x4041e6E3B54df2684c5b345d761CF13a1BC219b6;
      addrAZUKI = 0x292F693048208184320C01e0C223D624268e5EE7;

      addrYieldLido = 0x59303f797B8Dd80fc3743047df63C76E44Ca7CBd;
      addrYieldEtherfi = 0x3234F1047E71421Ec67A576D87eaEe1B86E8A1Ea;
      addrYieldSDai = 0x7464a51fA6338A34b694b4bF4A152781fb2C4B70;

      commonPoolId = 1;
      addrIrmYield = 0x10988B9c7e7048B83D590b14F0167FDe56728Ae9;
    } else {
      revert('chainid not support');
    }

    address addressProvider_ = config.getAddressProvider();
    require(addressProvider_ != address(0), 'Invalid AddressProvider in config');
    addressProvider = AddressProvider(addressProvider_);
    priceOracle = PriceOracle(addressProvider.getPriceOracle());
    configuratorPool = ConfiguratorPool(addressProvider.getPoolModuleProxy(Constants.MODULEID__CONFIGURATOR_POOL));
    configurator = Configurator(addressProvider.getPoolModuleProxy(Constants.MODULEID__CONFIGURATOR));

    //initYieldPools();

    initYieldLido();

    initYieldEtherfi();

    initYieldSDai();
  }

  function initYieldPools() internal {
    configuratorPool.setPoolYieldEnable(commonPoolId, true);

    IERC20Metadata weth = IERC20Metadata(addrWETH);
    configurator.setAssetYieldEnable(commonPoolId, address(weth), true);
    configurator.setAssetYieldCap(commonPoolId, address(weth), 2000);
    configurator.setAssetYieldRate(commonPoolId, address(weth), address(addrIrmYield));

    IERC20Metadata dai = IERC20Metadata(addrDAI);
    configurator.setAssetYieldEnable(commonPoolId, address(dai), true);
    configurator.setAssetYieldCap(commonPoolId, address(dai), 2000);
    configurator.setAssetYieldRate(commonPoolId, address(dai), address(addrIrmYield));
  }

  function initYieldLido() internal {
    configurator.setManagerYieldCap(commonPoolId, address(addrYieldLido), address(addrWETH), 2000);

    YieldEthStakingLido yieldEthStakingLido = YieldEthStakingLido(payable(addrYieldLido));

    yieldEthStakingLido.setNftActive(address(addrWPUNK), true);
    yieldEthStakingLido.setNftStakeParams(address(addrWPUNK), 50000, 9000);
    yieldEthStakingLido.setNftUnstakeParams(address(addrWPUNK), 0.01 ether, 1.05e18);

    yieldEthStakingLido.setNftActive(address(addrBAYC), true);
    yieldEthStakingLido.setNftStakeParams(address(addrBAYC), 50000, 9000);
    yieldEthStakingLido.setNftUnstakeParams(address(addrBAYC), 0.01 ether, 1.05e18);

    yieldEthStakingLido.setNftActive(address(addrStBAYC), true);
    yieldEthStakingLido.setNftStakeParams(address(addrStBAYC), 50000, 9000);
    yieldEthStakingLido.setNftUnstakeParams(address(addrStBAYC), 0.01 ether, 1.05e18);

    yieldEthStakingLido.setNftActive(address(addrPPG), true);
    yieldEthStakingLido.setNftStakeParams(address(addrPPG), 50000, 9000);
    yieldEthStakingLido.setNftUnstakeParams(address(addrPPG), 0.01 ether, 1.05e18);

    yieldEthStakingLido.setNftActive(address(addrAZUKI), true);
    yieldEthStakingLido.setNftStakeParams(address(addrAZUKI), 50000, 9000);
    yieldEthStakingLido.setNftUnstakeParams(address(addrAZUKI), 0.01 ether, 1.05e18);
  }

  function initYieldEtherfi() internal {
    configurator.setManagerYieldCap(commonPoolId, address(addrYieldEtherfi), address(addrWETH), 2000);

    YieldEthStakingEtherfi yieldEthStakingEtherfi = YieldEthStakingEtherfi(payable(addrYieldEtherfi));

    yieldEthStakingEtherfi.setNftActive(address(addrWPUNK), true);
    yieldEthStakingEtherfi.setNftStakeParams(address(addrWPUNK), 20000, 9000);
    yieldEthStakingEtherfi.setNftUnstakeParams(address(addrWPUNK), 0.01 ether, 1.05e18);

    yieldEthStakingEtherfi.setNftActive(address(addrBAYC), true);
    yieldEthStakingEtherfi.setNftStakeParams(address(addrBAYC), 20000, 9000);
    yieldEthStakingEtherfi.setNftUnstakeParams(address(addrBAYC), 0.01 ether, 1.05e18);

    yieldEthStakingEtherfi.setNftActive(address(addrStBAYC), true);
    yieldEthStakingEtherfi.setNftStakeParams(address(addrStBAYC), 20000, 9000);
    yieldEthStakingEtherfi.setNftUnstakeParams(address(addrStBAYC), 0.01 ether, 1.05e18);

    yieldEthStakingEtherfi.setNftActive(address(addrPPG), true);
    yieldEthStakingEtherfi.setNftStakeParams(address(addrPPG), 20000, 9000);
    yieldEthStakingEtherfi.setNftUnstakeParams(address(addrPPG), 0.01 ether, 1.05e18);

    yieldEthStakingEtherfi.setNftActive(address(addrAZUKI), true);
    yieldEthStakingEtherfi.setNftStakeParams(address(addrAZUKI), 20000, 9000);
    yieldEthStakingEtherfi.setNftUnstakeParams(address(addrAZUKI), 0.01 ether, 1.05e18);
  }

  function initYieldSDai() internal {
    configurator.setManagerYieldCap(commonPoolId, address(addrYieldSDai), address(addrDAI), 2000);

    YieldSavingsDai yieldSDai = YieldSavingsDai(payable(addrYieldSDai));

    yieldSDai.setNftActive(address(addrWPUNK), true);
    yieldSDai.setNftStakeParams(address(addrWPUNK), 50000, 9000);
    yieldSDai.setNftUnstakeParams(address(addrWPUNK), 100e18, 1.05e18);

    yieldSDai.setNftActive(address(addrBAYC), true);
    yieldSDai.setNftStakeParams(address(addrBAYC), 50000, 9000);
    yieldSDai.setNftUnstakeParams(address(addrBAYC), 100e18, 1.05e18);

    yieldSDai.setNftActive(address(addrStBAYC), true);
    yieldSDai.setNftStakeParams(address(addrStBAYC), 50000, 9000);
    yieldSDai.setNftUnstakeParams(address(addrStBAYC), 100e18, 1.05e18);

    yieldSDai.setNftActive(address(addrPPG), true);
    yieldSDai.setNftStakeParams(address(addrPPG), 50000, 9000);
    yieldSDai.setNftUnstakeParams(address(addrPPG), 100e18, 1.05e18);

    yieldSDai.setNftActive(address(addrAZUKI), true);
    yieldSDai.setNftStakeParams(address(addrAZUKI), 50000, 9000);
    yieldSDai.setNftUnstakeParams(address(addrAZUKI), 100e18, 1.05e18);
  }
}
