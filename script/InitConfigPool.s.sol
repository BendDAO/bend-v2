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
  address internal addrUSDS;

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

  address internal addrNFTOracle;
  address internal addrCLAggWETH;
  address internal addrCLAggUSDT;
  address internal addrCLAggUSDC;
  address internal addrCLAggDAI;

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
    if (block.chainid == 1) {
      // mainnet
      addrWETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
      addrUSDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
      addrUSDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
      addrDAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
      addrUSDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

      addrWPUNK = 0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6;
      addrBAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
      addrStBAYC = 0x08f5F0126aF89B4fD5499E942891D904A027624B;
      addrMAYC = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
      addrStMAYC = 0xc1ED28E4b4d8e284A41E7474CA5522b010f3A64F;
      addrPPG = 0xBd3531dA5CF5857e7CfAA92426877b022e612cf8;
      addrAZUKI = 0xED5AF388653567Af2F388E6224dC7C4b3241C544;
      addrMIL = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5;
      addrDOODLE = 0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e;
      addrMOONBIRD = 0x23581767a106ae21c074b2276D25e5C3e136a68b;
      addrCloneX = 0x49cF6f5d44E70224e2E23fDcdd2C053F30aDA28B;

      addrNFTOracle = 0x7C2A19e54e48718f6C60908a9Cff3396E4Ea1eBA;
      addrCLAggWETH = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
      addrCLAggUSDT = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
      addrCLAggUSDC = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
      addrCLAggDAI = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;

      commonPoolId = 1;

      irmDefault = DefaultInterestRateModel(0x209759aBCB4d2eA1B0Fc285042C2BCdbfd124123);
      irmYield = irmDefault;
      irmLow = irmDefault;
      irmMiddle = irmDefault;
      irmHigh = irmDefault;
    } else if (block.chainid == 11155111) {
      // sepolia
      addrWETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
      addrUSDT = 0x53cEd787Ba91B4f872b961914faE013ccF8b0236;
      addrUSDC = 0xC188f878304F37e7199dFBd114e2Af68D043d98c;
      addrDAI = 0xf9a88B0cc31f248c89F063C2928fA10e5A029B88;
      addrUSDS = 0x99f5A9506504BB96d0019538608090015BA9EBDd;

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

      addrNFTOracle = 0xF143144Fb2703C8aeefD0c4D06d29F5Bb0a9C60A;
      addrCLAggWETH = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
      addrCLAggUSDT = 0x382c1856D25CbB835D4C1d732EB69f3e0d9Ba104;
      addrCLAggUSDC = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
      addrCLAggDAI = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;

      commonPoolId = 1;

      irmDefault = DefaultInterestRateModel(0x3a6a42c547B264AB3717aD127e5f07960Fe21306);
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

    // initCommonPools();

    // listingUSDS(commonPoolId);

    // initInterestRateModels(1);
    // initInterestRateModels(2);
    // initInterestRateModels(3);

    setPoolInterestRateModels(1);
    setPoolInterestRateModels(2);
    setPoolInterestRateModels(3);
  }

  function listingUSDS(uint32 poolId) internal {
    irmDefault.setInterestRateParams(
      poolId,
      addrUSDS,
      yieldRateGroupId,
      (75 * WadRayMath.RAY) / 100,
      (2 * WadRayMath.RAY) / 100, // baseRate
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      poolId,
      addrUSDS,
      lowRateGroupId,
      (75 * WadRayMath.RAY) / 100,
      (6 * WadRayMath.RAY) / 100, // baseRate
      (4 * WadRayMath.RAY) / 100,
      (80 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      poolId,
      addrUSDS,
      middleRateGroupId,
      (75 * WadRayMath.RAY) / 100,
      (8 * WadRayMath.RAY) / 100, // baseRate
      (4 * WadRayMath.RAY) / 100,
      (80 * WadRayMath.RAY) / 100
    );
    irmDefault.setInterestRateParams(
      poolId,
      addrUSDS,
      highRateGroupId,
      (75 * WadRayMath.RAY) / 100,
      (10 * WadRayMath.RAY) / 100, // baseRate
      (4 * WadRayMath.RAY) / 100,
      (80 * WadRayMath.RAY) / 100
    );

    addUSDS(poolId);

    configurator.setAssetBorrowing(poolId, addrUSDS, true);
    configurator.setAssetFlashLoan(poolId, addrUSDS, true);
  }

  function initOralces() internal {
    priceOracle.setBendNFTOracle(addrNFTOracle);

    address[] memory assets = new address[](4);
    assets[0] = address(addrWETH);
    assets[1] = address(addrUSDT);
    assets[2] = address(addrUSDC);
    assets[3] = address(addrDAI);
    address[] memory aggs = new address[](4);
    aggs[0] = address(addrCLAggWETH);
    aggs[1] = address(addrCLAggUSDT);
    aggs[2] = address(addrCLAggUSDC);
    aggs[3] = address(addrCLAggDAI);
    priceOracle.setAssetChainlinkAggregators(assets, aggs);
  }

  function initInterestRateModels(uint32 poolId) internal {
    // WETH
    if (poolId == 1 || poolId == 2) {
      irmDefault.setInterestRateParams(
        poolId,
        addrWETH,
        yieldRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (1 * WadRayMath.RAY) / 100, // baseRate
        (1 * WadRayMath.RAY) / 100,
        (20 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrWETH,
        lowRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (5 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrWETH,
        middleRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (7 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrWETH,
        highRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (9 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
    }

    // USDT
    if (poolId == 1 || poolId == 2 || poolId == 3) {
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDT,
        yieldRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (2 * WadRayMath.RAY) / 100, // baseRate
        (1 * WadRayMath.RAY) / 100,
        (20 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDT,
        lowRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (5 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDT,
        middleRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (7 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDT,
        highRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (9 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
    }

    // USDC
    if (poolId == 1) {
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDC,
        yieldRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (2 * WadRayMath.RAY) / 100, // baseRate
        (1 * WadRayMath.RAY) / 100,
        (20 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDC,
        lowRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (5 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDC,
        middleRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (7 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDC,
        highRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (9 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
    }

    // DAI
    if (poolId == 1 || poolId == 3) {
      irmDefault.setInterestRateParams(
        poolId,
        addrDAI,
        yieldRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (2 * WadRayMath.RAY) / 100, // baseRate
        (1 * WadRayMath.RAY) / 100,
        (20 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrDAI,
        lowRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (6 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrDAI,
        middleRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (8 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrDAI,
        highRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (10 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
    }

    // USDS
    if (poolId == 1) {
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDS,
        yieldRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (2 * WadRayMath.RAY) / 100, // baseRate
        (1 * WadRayMath.RAY) / 100,
        (20 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDS,
        lowRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (6 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDS,
        middleRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (8 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
      irmDefault.setInterestRateParams(
        poolId,
        addrUSDS,
        highRateGroupId,
        (75 * WadRayMath.RAY) / 100,
        (10 * WadRayMath.RAY) / 100, // baseRate
        (4 * WadRayMath.RAY) / 100,
        (80 * WadRayMath.RAY) / 100
      );
    }
  }

  function setPoolInterestRateModels(uint32 poolId) internal {
    if (poolId == 1 || poolId == 2) {
      setAssetInterestRateModels(poolId, addrWETH);
    }

    if (poolId == 1 || poolId == 2 || poolId == 3) {
      setAssetInterestRateModels(poolId, addrUSDT);
    }

    if (poolId == 1) {
      setAssetInterestRateModels(poolId, addrUSDC);
    }

    if (poolId == 1 || poolId == 3) {
      setAssetInterestRateModels(poolId, addrDAI);
    }

    if (poolId == 1) {
      setAssetInterestRateModels(poolId, addrUSDS);
    }
  }

  function setAssetInterestRateModels(uint32 poolId, address asset) internal {
    configurator.setAssetLendingRate(poolId, asset, lowRateGroupId, address(irmDefault));
    configurator.setAssetLendingRate(poolId, asset, middleRateGroupId, address(irmDefault));
    configurator.setAssetLendingRate(poolId, asset, highRateGroupId, address(irmDefault));
    if ((poolId == 1) && (asset == addrWETH || asset == addrDAI || asset == addrUSDS)) {
      configurator.setAssetYieldRate(poolId, asset, address(irmDefault));
    }
  }

  function initCommonPools() internal {
    commonPoolId = createNewPool('BendDAO Pool');

    // erc20 assets
    addWETH(commonPoolId);
    addUSDT(commonPoolId);
    addUSDC(commonPoolId);
    addDAI(commonPoolId);
    addUSDS(commonPoolId);

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
    configurator.setAssetSupplyCap(poolId, address(token), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(token), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(token), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(token), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(token), highRateGroupId, address(irmHigh));
  }

  function addUSDC(uint32 poolId) internal {
    IERC20Metadata token = IERC20Metadata(addrUSDC);
    uint8 decimals = token.decimals();

    configurator.addAssetERC20(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 7500, 7800, 450);
    configurator.setAssetProtocolFee(poolId, address(token), 1000);
    configurator.setAssetClassGroup(poolId, address(token), lowRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
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
    configurator.setAssetSupplyCap(poolId, address(token), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(token), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(token), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(token), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(token), highRateGroupId, address(irmHigh));
  }

  function addUSDS(uint32 poolId) internal {
    IERC20Metadata token = IERC20Metadata(addrUSDS);
    uint8 decimals = token.decimals();

    configurator.addAssetERC20(poolId, address(token));

    configurator.setAssetCollateralParams(poolId, address(token), 7500, 7800, 750);
    configurator.setAssetProtocolFee(poolId, address(token), 1000);
    configurator.setAssetClassGroup(poolId, address(token), lowRateGroupId);
    configurator.setAssetActive(poolId, address(token), true);
    configurator.setAssetSupplyCap(poolId, address(token), 100_000_000 * (10 ** decimals));
    configurator.setAssetBorrowCap(poolId, address(token), 100_000_000 * (10 ** decimals));

    configurator.addAssetGroup(poolId, address(token), lowRateGroupId, address(irmLow));
    configurator.addAssetGroup(poolId, address(token), middleRateGroupId, address(irmMiddle));
    configurator.addAssetGroup(poolId, address(token), highRateGroupId, address(irmHigh));
  }

  function setAssetBorrowing(uint32 poolId) internal {
    configurator.setAssetBorrowing(poolId, addrWETH, true);
    configurator.setAssetBorrowing(poolId, addrUSDT, true);
    configurator.setAssetBorrowing(poolId, addrUSDC, true);
    configurator.setAssetBorrowing(poolId, addrDAI, true);
    configurator.setAssetBorrowing(poolId, addrUSDS, true);
  }

  function setAssetFlashLoan(uint32 poolId) internal {
    configurator.setAssetFlashLoan(poolId, addrWETH, true);
    configurator.setAssetFlashLoan(poolId, addrUSDT, true);
    configurator.setAssetFlashLoan(poolId, addrUSDC, true);
    configurator.setAssetFlashLoan(poolId, addrDAI, true);
    configurator.setAssetFlashLoan(poolId, addrUSDS, true);
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
