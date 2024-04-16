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

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract InitConfigSepolia is DeployBase {
  using ConfigLib for Config;

  AddressProvider internal addressProvider;
  PriceOracle internal priceOracle;
  Configurator internal configurator;

  DefaultInterestRateModel irmYield;
  DefaultInterestRateModel irmLow;
  DefaultInterestRateModel irmMiddle;
  DefaultInterestRateModel irmHigh;
  uint32 commonPoolId;
  uint8 constant lowRateGroupId = 1;
  uint8 constant middleRateGroupId = 2;
  uint8 constant highRateGroupId = 3;

  function _deploy() internal virtual override {
    require(block.chainid == 11155111, 'chainid not sepolia');

    address addressProvider_ = config.getAddressProvider();
    require(addressProvider_ != address(0), 'Invalid AddressProvider in config');
    addressProvider = AddressProvider(addressProvider_);
    priceOracle = PriceOracle(addressProvider.getPriceOracle());
    configurator = Configurator(addressProvider.getPoolModuleProxy(Constants.MODULEID__CONFIGURATOR));

    initInterestRateModels();

    initOralces();

    initCommonPools();

    addERC20Assets();

    addERC721Assets();
  }

  function initOralces() internal {
    priceOracle.setBendNFTOracle(0xF143144Fb2703C8aeefD0c4D06d29F5Bb0a9C60A);

    address[] memory assets = new address[](2);
    assets[0] = address(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
    assets[1] = address(0x53cEd787Ba91B4f872b961914faE013ccF8b0236);
    address[] memory aggs = new address[](2);
    aggs[0] = address(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    aggs[1] = address(0x382c1856D25CbB835D4C1d732EB69f3e0d9Ba104);
    priceOracle.setAssetChainlinkAggregators(assets, aggs);
  }

  function initInterestRateModels() internal {
    // Interest Rate Model
    irmYield = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (1 * WadRayMath.RAY) / 100, // baseRate
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    irmLow = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    irmMiddle = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (8 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    irmHigh = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (10 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
  }

  function initCommonPools() internal {
    // pool
    commonPoolId = configurator.createPool('Common Pool');

    // group
    configurator.addPoolGroup(commonPoolId, lowRateGroupId);
    configurator.addPoolGroup(commonPoolId, middleRateGroupId);
    configurator.addPoolGroup(commonPoolId, highRateGroupId);
  }

  function addERC20Assets() internal {
    uint8 decimals;
    IERC20Metadata weth = IERC20Metadata(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
    decimals = weth.decimals();
    configurator.addAssetERC20(commonPoolId, address(weth));
    configurator.setAssetCollateralParams(commonPoolId, address(weth), 8050, 8300, 500);
    configurator.setAssetProtocolFee(commonPoolId, address(weth), 2000);
    configurator.setAssetClassGroup(commonPoolId, address(weth), lowRateGroupId);
    configurator.setAssetActive(commonPoolId, address(weth), true);
    configurator.setAssetBorrowing(commonPoolId, address(weth), true);
    configurator.setAssetSupplyCap(commonPoolId, address(weth), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(commonPoolId, address(weth), 100_000_000 * (10 ** decimals));
    configurator.addAssetGroup(commonPoolId, address(weth), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(commonPoolId, address(weth), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(commonPoolId, address(weth), highRateGroupId, address(irmHigh));

    IERC20Metadata usdt = IERC20Metadata(0x53cEd787Ba91B4f872b961914faE013ccF8b0236);
    decimals = usdt.decimals();
    configurator.addAssetERC20(commonPoolId, address(usdt));
    configurator.setAssetCollateralParams(commonPoolId, address(usdt), 7400, 7600, 450);
    configurator.setAssetProtocolFee(commonPoolId, address(usdt), 2000);
    configurator.setAssetClassGroup(commonPoolId, address(usdt), lowRateGroupId);
    configurator.setAssetActive(commonPoolId, address(usdt), true);
    configurator.setAssetBorrowing(commonPoolId, address(usdt), true);
    configurator.setAssetSupplyCap(commonPoolId, address(usdt), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(commonPoolId, address(usdt), 100_000_000 * (10 ** decimals));
    configurator.addAssetGroup(commonPoolId, address(usdt), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(commonPoolId, address(usdt), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(commonPoolId, address(usdt), highRateGroupId, address(irmHigh));
  }

  function addERC721Assets() internal {
    IERC721 wpunk = IERC721(0x647dc527Bd7dFEE4DD468cE6fC62FC50fa42BD8b);
    configurator.addAssetERC721(commonPoolId, address(wpunk));
    configurator.setAssetCollateralParams(commonPoolId, address(wpunk), 6000, 8000, 1000);
    configurator.setAssetAuctionParams(commonPoolId, address(wpunk), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(commonPoolId, address(wpunk), lowRateGroupId);
    configurator.setAssetActive(commonPoolId, address(wpunk), true);
    configurator.setAssetSupplyCap(commonPoolId, address(wpunk), 10_000);

    IERC721 bayc = IERC721(0xE15A78992dd4a9d6833eA7C9643650d3b0a2eD2B);
    configurator.addAssetERC721(commonPoolId, address(bayc));
    configurator.setAssetCollateralParams(commonPoolId, address(bayc), 6000, 8000, 1000);
    configurator.setAssetAuctionParams(commonPoolId, address(bayc), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(commonPoolId, address(bayc), lowRateGroupId);
    configurator.setAssetActive(commonPoolId, address(bayc), true);
    configurator.setAssetSupplyCap(commonPoolId, address(bayc), 10_000);

    IERC721 mayc = IERC721(0xD0ff8ae7E3D9591605505D3db9C33b96c4809CDC);
    configurator.addAssetERC721(commonPoolId, address(mayc));
    configurator.setAssetCollateralParams(commonPoolId, address(mayc), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(commonPoolId, address(mayc), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(commonPoolId, address(mayc), highRateGroupId);
    configurator.setAssetActive(commonPoolId, address(mayc), true);
    configurator.setAssetSupplyCap(commonPoolId, address(mayc), 10_000);
  }
}
