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

import {Configured, ConfigLib, Config} from 'config/Configured.sol';
import {DeployBase} from './DeployBase.s.sol';

import '@forge-std/Script.sol';

contract InitConfigPool is DeployBase {
  using ConfigLib for Config;

  address internal addrWETH;
  address internal addrUSDT;
  address internal addrUSDC;
  address internal addrDAI;

  address internal addrWPUNK;
  address internal addrBAYC;
  address internal addrStBAYC;
  address internal addrMAYC;
  address internal addrStMAYC;
  address internal addrPPG;
  address internal addrAZUKI;
  address internal addrMIL;
  address internal addrDOODLE;
  address internal addrMOONBIRD;
  address internal addrCloneX;

  AddressProvider internal addressProvider;
  PriceOracle internal priceOracle;
  ConfiguratorPool internal configuratorPool;
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
      addrUSDC = 0xC188f878304F37e7199dFBd114e2Af68D043d98c;
      addrDAI = 0xf9a88B0cc31f248c89F063C2928fA10e5A029B88;

      addrWPUNK = 0x647dc527Bd7dFEE4DD468cE6fC62FC50fa42BD8b;
      addrBAYC = 0xE15A78992dd4a9d6833eA7C9643650d3b0a2eD2B;
      addrStBAYC = 0x214455B76E5A5dECB48557417397B831efC6219b;
      addrMAYC = 0xD0ff8ae7E3D9591605505D3db9C33b96c4809CDC;
      addrStMAYC = 0xE5165Aae8D50371A277f266eC5A0E00405B532C8;
      addrPPG = 0x4041e6E3B54df2684c5b345d761CF13a1BC219b6;
      addrAZUKI = 0x292F693048208184320C01e0C223D624268e5EE7;
      addrMIL = 0xBE4CC856225945ea80460899ff2Fbf0143358550;
      addrDOODLE = 0x28cCcd47Aa3FFb42D77e395Fba7cdAcCeA884d5A;
      addrMOONBIRD = 0x4e3A064eF42DD916347751DfA7Ca1dcbA49d3DA8;
      addrCloneX = 0x3BD0A71D39E67fc49D5A6645550f2bc95F5cb398;

      commonPoolId = 1;

      irmDefault = DefaultInterestRateModel(0x10988B9c7e7048B83D590b14F0167FDe56728Ae9);
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
    configuratorPool = ConfiguratorPool(addressProvider.getPoolModuleProxy(Constants.MODULEID__CONFIGURATOR_POOL));
    configurator = Configurator(addressProvider.getPoolModuleProxy(Constants.MODULEID__CONFIGURATOR));

    //initInterestRateModels();

    //setPoolInterestRateModels(1);
    //setPoolInterestRateModels(2);
    //setPoolInterestRateModels(3);

    //initOralces();

    //initCommonPools();

    //initPunksPools();

    //initStableCoinPools();

    //setFlashLoan(1);

    configurator.setAssetClassGroup(1, address(addrWPUNK), middleRateGroupId);
    configurator.setAssetClassGroup(1, address(addrBAYC), middleRateGroupId);
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

  function setPoolInterestRateModels(uint32 poolId) internal {
    if (poolId == 1 || poolId == 2) {
      setAssetInterestRateModels(poolId, addrWETH);
    }

    if (poolId == 1 || poolId == 2 || poolId == 3) {
      setAssetInterestRateModels(poolId, addrUSDT);
    }

    if (poolId == 1 || poolId == 3) {
      setAssetInterestRateModels(poolId, addrDAI);
    }
  }

  function setAssetInterestRateModels(uint32 poolId, address asset) internal {
    configurator.setAssetLendingRate(poolId, asset, lowRateGroupId, address(irmDefault));
    configurator.setAssetLendingRate(poolId, asset, middleRateGroupId, address(irmDefault));
    configurator.setAssetLendingRate(poolId, asset, highRateGroupId, address(irmDefault));
    configurator.setAssetYieldRate(poolId, asset, address(irmDefault));
  }

  function initCommonPools() internal {
    commonPoolId = createNewPool('Common Pool');

    // erc20 assets
    addWETH(commonPoolId);
    addUSDT(commonPoolId);
    addUSDC(commonPoolId);
    addDAI(commonPoolId);

    // erc721 assets
    addWPUNK(commonPoolId);
    addBAYC(commonPoolId);
    addMAYC(commonPoolId);
    addStBAYC(commonPoolId);
    addStMAYC(commonPoolId);
    addPPG(commonPoolId);
    addAzuki(commonPoolId);
    addMIL(commonPoolId);
    addDoodle(commonPoolId);
    addMoonbird(commonPoolId);
    addCloneX(commonPoolId);
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
    uint32 poolId = configuratorPool.createPool(name);

    // group
    configuratorPool.addPoolGroup(poolId, lowRateGroupId);
    configuratorPool.addPoolGroup(poolId, middleRateGroupId);
    configuratorPool.addPoolGroup(poolId, highRateGroupId);

    return poolId;
  }

  function addWETH(uint32 poolId) internal {
    IERC20Metadata token = IERC20Metadata(addrWETH);
    uint8 decimals = token.decimals();

    configurator.addAssetERC20(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 8050, 8300, 500);
    configurator.setAssetProtocolFee(poolId, address(token), 1500);
    configurator.setAssetClassGroup(poolId, address(token), lowRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetBorrowing(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(token), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(token), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(token), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(token), highRateGroupId, address(irmHigh));
  }

  function addUSDT(uint32 poolId) internal {
    IERC20Metadata token = IERC20Metadata(addrUSDT);
    uint8 decimals = token.decimals();

    configurator.addAssetERC20(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 7500, 7800, 450);
    configurator.setAssetProtocolFee(poolId, address(token), 1000);
    configurator.setAssetClassGroup(poolId, address(token), lowRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetBorrowing(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(token), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(token), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(token), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(token), highRateGroupId, address(irmHigh));
  }

  function addUSDC(uint32 poolId) internal {
    IERC20Metadata token = IERC20Metadata(addrUSDC);
    uint8 decimals = token.decimals();

    //configurator.addAssetERC20(poolId, address(token));

    //configurator.setAssetCollateralParams(poolId, address(token), 7500, 7800, 450);
    //configurator.setAssetProtocolFee(poolId, address(token), 1000);
    configurator.setAssetClassGroup(poolId, address(token), lowRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetBorrowing(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(token), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(token), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(token), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(token), highRateGroupId, address(irmHigh));
  }

  function addDAI(uint32 poolId) internal {
    IERC20Metadata token = IERC20Metadata(addrDAI);
    uint8 decimals = token.decimals();

    configurator.addAssetERC20(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 6300, 7700, 500);
    configurator.setAssetProtocolFee(poolId, address(token), 2500);
    configurator.setAssetClassGroup(poolId, address(token), lowRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetBorrowing(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(token), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(token), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(token), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(token), highRateGroupId, address(irmHigh));
  }

  function setFlashLoan(uint32 poolId) internal {
    configurator.setAssetFlashLoan(poolId, addrWETH, true);
    configurator.setAssetFlashLoan(poolId, addrUSDT, true);
    configurator.setAssetFlashLoan(poolId, addrUSDC, true);
    configurator.setAssetFlashLoan(poolId, addrDAI, true);
  }

  function addWPUNK(uint32 poolId) internal {
    IERC721 token = IERC721(addrWPUNK);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addBAYC(uint32 poolId) internal {
    IERC721 token = IERC721(addrBAYC);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addStBAYC(uint32 poolId) internal {
    IERC721 token = IERC721(addrStBAYC);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addMAYC(uint32 poolId) internal {
    IERC721 token = IERC721(addrMAYC);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addStMAYC(uint32 poolId) internal {
    IERC721 token = IERC721(addrStMAYC);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addPPG(uint32 poolId) internal {
    IERC721 token = IERC721(addrPPG);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addAzuki(uint32 poolId) internal {
    IERC721 token = IERC721(addrAZUKI);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addMIL(uint32 poolId) internal {
    IERC721 token = IERC721(addrMIL);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), middleRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addMoonbird(uint32 poolId) internal {
    IERC721 token = IERC721(addrMOONBIRD);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), highRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addDoodle(uint32 poolId) internal {
    IERC721 token = IERC721(addrDOODLE);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), highRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }

  function addCloneX(uint32 poolId) internal {
    IERC721 token = IERC721(addrCloneX);

    configurator.addAssetERC721(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 5000, 8000, 1000);
    configurator.setAssetAuctionParams(poolId, address(token), 5000, 500, 2000, 1 days);
    configurator.setAssetClassGroup(poolId, address(token), highRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 10_000);
  }
}
