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

contract InitConfigPool is DeployBase {
  using ConfigLib for Config;

  address internal addrWETH;
  address internal addrUSDT;
  address internal addrDAI;

  address internal addrWPUNK;
  address internal addrBAYC;
  address internal addrMAYC;

  AddressProvider internal addressProvider;
  PriceOracle internal priceOracle;
  Configurator internal configurator;

  DefaultInterestRateModel internal irmDefault;
  DefaultInterestRateModel internal irmYield;
  DefaultInterestRateModel internal irmLow;
  DefaultInterestRateModel internal irmMiddle;
  DefaultInterestRateModel internal irmHigh;
  uint32 internal commonPoolId;
  uint8 internal constant yieldRateGroupId = 0;
  uint8 internal constant lowRateGroupId = 1;
  uint8 internal constant middleRateGroupId = 2;
  uint8 internal constant highRateGroupId = 3;

  function _deploy() internal virtual override {
    if (block.chainid == 11155111) {
      addrWETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
      addrUSDT = 0x53cEd787Ba91B4f872b961914faE013ccF8b0236;
      addrDAI = 0xf9a88B0cc31f248c89F063C2928fA10e5A029B88;

      addrWPUNK = 0x647dc527Bd7dFEE4DD468cE6fC62FC50fa42BD8b;
      addrBAYC = 0xE15A78992dd4a9d6833eA7C9643650d3b0a2eD2B;
      addrMAYC = 0xD0ff8ae7E3D9591605505D3db9C33b96c4809CDC;

      commonPoolId = 1;

      irmDefault = DefaultInterestRateModel(0xBD9859043CdDD4310e37CA87F37A829B488F2B4F);
      irmYield = irmDefault;
      irmLow = irmDefault;
      irmMiddle = irmDefault;
      irmHigh = irmDefault;
    } else {
      revert('chainid not support');
    }

    address addressProvider_ = config.getAddressProvider();
    require(addressProvider_ != address(0), 'Invalid AddressProvider in config');
    addressProvider = AddressProvider(addressProvider_);
    priceOracle = PriceOracle(addressProvider.getPriceOracle());
    configurator = Configurator(addressProvider.getPoolModuleProxy(Constants.MODULEID__CONFIGURATOR));

    //initInterestRateModels();

    //initOralces();

    //initCommonPools();

    //initPunksPools();

    //initStableCoinPools();

    //setFlashLoan(1);
  }

  function initOralces() internal {
    priceOracle.setBendNFTOracle(0xF143144Fb2703C8aeefD0c4D06d29F5Bb0a9C60A);

    address[] memory assets = new address[](3);
    assets[0] = address(addrWETH);
    assets[1] = address(addrUSDT);
    assets[2] = address(addrDAI);
    address[] memory aggs = new address[](3);
    aggs[0] = address(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    aggs[1] = address(0x382c1856D25CbB835D4C1d732EB69f3e0d9Ba104);
    aggs[2] = address(0x14866185B1962B63C3Ea9E03Bc1da838bab34C19);
    priceOracle.setAssetChainlinkAggregators(assets, aggs);
  }

  function initInterestRateModels() internal {
    // Interest Rate Model
    irmDefault = new DefaultInterestRateModel(address(addressProvider));

    // WETH
    irmDefault.setInterestRateParams(
      addrWETH,
      yieldRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (1 * WadRayMath.RAY) / 100, // baseRate
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrWETH,
      lowRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrWETH,
      middleRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (8 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrWETH,
      highRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (10 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );

    // USDT
    irmDefault.setInterestRateParams(
      addrUSDT,
      yieldRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (1 * WadRayMath.RAY) / 100, // baseRate
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrUSDT,
      lowRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100, // baseRate
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrUSDT,
      middleRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (8 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrUSDT,
      highRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (10 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );

    // DAI
    irmDefault.setInterestRateParams(
      addrDAI,
      yieldRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (1 * WadRayMath.RAY) / 100, // baseRate
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrDAI,
      lowRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100, // baseRate
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrDAI,
      middleRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (8 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      addrDAI,
      highRateGroupId,
      (65 * WadRayMath.RAY) / 100,
      (10 * WadRayMath.RAY) / 100, // baseRate
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
  }

  function initCommonPools() internal {
    commonPoolId = createNewPool('Common Pool');

    // erc20 assets
    addWETH(commonPoolId);
    addUSDT(commonPoolId);
    addDAI(commonPoolId);

    // erc721 assets
    addWPUNK(commonPoolId);
    addBAYC(commonPoolId);
    addMAYC(commonPoolId);
  }

  function initPunksPools() internal {
    uint32 poolId = createNewPool('CryptoPunks Pool');

    // erc20 assets
    addWETH(poolId);
    addUSDT(poolId);

    // erc721 assets
    addWPUNK(poolId);
  }

  function initStableCoinPools() internal {
    uint32 poolId = createNewPool('StableCoin Pool');

    // erc20 assets
    addUSDT(poolId);
    addDAI(poolId);
  }

  function createNewPool(string memory name) internal returns (uint32) {
    // pool
    uint32 poolId = configurator.createPool(name);

    // group
    configurator.addPoolGroup(poolId, lowRateGroupId);
    configurator.addPoolGroup(poolId, middleRateGroupId);
    configurator.addPoolGroup(poolId, highRateGroupId);

    return poolId;
  }

  function addWETH(uint32 poolId) internal {
    IERC20Metadata weth = IERC20Metadata(addrWETH);
    uint8 decimals = weth.decimals();

    configurator.addAssetERC20(poolId, address(weth));

    configurator.setAssetCollateralParams(poolId, address(weth), 8050, 8300, 500);
    configurator.setAssetProtocolFee(poolId, address(weth), 2000);
    configurator.setAssetClassGroup(poolId, address(weth), lowRateGroupId);
    configurator.setAssetActive(poolId, address(weth), true);
    configurator.setAssetBorrowing(poolId, address(weth), true);
    configurator.setAssetSupplyCap(poolId, address(weth), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(weth), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(weth), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(weth), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(weth), highRateGroupId, address(irmHigh));
  }

  function addUSDT(uint32 poolId) internal {
    IERC20Metadata usdt = IERC20Metadata(addrUSDT);
    uint8 decimals = usdt.decimals();

    configurator.addAssetERC20(poolId, address(usdt));

    configurator.setAssetCollateralParams(poolId, address(usdt), 7400, 7600, 450);
    configurator.setAssetProtocolFee(poolId, address(usdt), 2000);
    configurator.setAssetClassGroup(poolId, address(usdt), lowRateGroupId);
    configurator.setAssetActive(poolId, address(usdt), true);
    configurator.setAssetBorrowing(poolId, address(usdt), true);
    configurator.setAssetSupplyCap(poolId, address(usdt), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(usdt), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(usdt), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(usdt), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(usdt), highRateGroupId, address(irmHigh));
  }

  function addDAI(uint32 poolId) internal {
    IERC20Metadata dai = IERC20Metadata(addrDAI);
    uint8 decimals = dai.decimals();

    configurator.addAssetERC20(poolId, address(dai));

    configurator.setAssetCollateralParams(poolId, address(dai), 6300, 7700, 500);
    configurator.setAssetProtocolFee(poolId, address(dai), 2000);
    configurator.setAssetClassGroup(poolId, address(dai), lowRateGroupId);
    configurator.setAssetActive(poolId, address(dai), true);
    configurator.setAssetBorrowing(poolId, address(dai), true);
    configurator.setAssetSupplyCap(poolId, address(dai), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(dai), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(dai), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(dai), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(dai), highRateGroupId, address(irmHigh));
  }

  function setFlashLoan(uint32 poolId) internal {
    configurator.setAssetFlashLoan(poolId, addrWETH, true);
    configurator.setAssetFlashLoan(poolId, addrUSDT, true);
    configurator.setAssetFlashLoan(poolId, addrDAI, true);
  }

  function addWPUNK(uint32 poolId) internal {
    IERC721 wpunk = IERC721(addrWPUNK);

    configurator.addAssetERC721(poolId, address(wpunk));

    configurator.setAssetCollateralParams(poolId, address(wpunk), 6000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(wpunk), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(wpunk), lowRateGroupId);
    configurator.setAssetActive(poolId, address(wpunk), true);
    configurator.setAssetSupplyCap(poolId, address(wpunk), 10_000);
  }

  function addBAYC(uint32 poolId) internal {
    IERC721 bayc = IERC721(addrBAYC);

    configurator.addAssetERC721(poolId, address(bayc));

    configurator.setAssetCollateralParams(poolId, address(bayc), 6000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(bayc), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(bayc), lowRateGroupId);
    configurator.setAssetActive(poolId, address(bayc), true);
    configurator.setAssetSupplyCap(poolId, address(bayc), 10_000);
  }

  function addMAYC(uint32 poolId) internal {
    IERC721 mayc = IERC721(addrMAYC);

    configurator.addAssetERC721(poolId, address(mayc));

    configurator.setAssetCollateralParams(poolId, address(mayc), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(mayc), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(mayc), highRateGroupId);
    configurator.setAssetActive(poolId, address(mayc), true);
    configurator.setAssetSupplyCap(poolId, address(mayc), 10_000);
  }
}
