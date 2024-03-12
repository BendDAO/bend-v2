// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

import {IWETH} from 'src/interfaces/IWETH.sol';
import {ACLManager} from 'src/ACLManager.sol';
import {PriceOracle} from 'src/PriceOracle.sol';
import {DefaultInterestRateModel} from 'src/irm/DefaultInterestRateModel.sol';
import {PoolManager} from 'src/PoolManager.sol';

import {MockERC20} from 'test/mocks/MockERC20.sol';
import {MockERC721} from 'test/mocks/MockERC721.sol';
import {MockFaucet} from 'test/mocks/MockFaucet.sol';

import {MockBendNFTOracle} from 'test/mocks/MockBendNFTOracle.sol';
import {MockChainlinkAggregator} from 'test/mocks/MockChainlinkAggregator.sol';

import {TestUser} from '../helpers/TestUser.sol';
import {TestWithUtils} from './TestWithUtils.sol';

import '@forge-std/Test.sol';

abstract contract TestWithSetup is TestWithUtils {
  Vm public tsHEVM = Vm(HEVM_ADDRESS);

  uint256 public constant TS_INITIAL_BALANCE = 1_000_000;

  address public tsDeployer;
  address public tsAclAdmin;
  address public tsPoolAdmin;
  address public tsEmergencyAdmin;
  address public tsOracleAdmin;
  address public tsTreasury;

  MockFaucet public tsFaucet;
  MockERC20 public tsWETH;
  MockERC20 public tsDAI;
  MockERC20 public tsUSDT;
  MockERC721 public tsWPUNK;
  MockERC721 public tsBAYC;
  MockERC721 public tsMAYC;

  MockBendNFTOracle public tsBendNFTOracle;
  MockChainlinkAggregator tsCLAggregatorWETH;
  MockChainlinkAggregator tsCLAggregatorDAI;
  MockChainlinkAggregator tsCLAggregatorUSDT;

  ProxyAdmin public tsProxyAdmin;
  ACLManager public tsAclManager;
  PriceOracle public tsPriceOracle;
  PoolManager public tsPoolManager;

  uint32 public tsCommonPoolId;
  uint8 public tsLowRateGroupId;
  uint8 public tsMiddleRateGroupId;
  uint8 public tsHighRateGroupId;

  DefaultInterestRateModel public tsYieldRateIRM;
  DefaultInterestRateModel public tsLowRateIRM;
  DefaultInterestRateModel public tsMiddleRateIRM;
  DefaultInterestRateModel public tsHighRateIRM;

  TestUser public tsDepositor1;
  TestUser public tsDepositor2;
  TestUser public tsDepositor3;
  TestUser[] public tsDepositors;

  TestUser public tsBorrower1;
  TestUser public tsBorrower2;
  TestUser public tsBorrower3;
  TestUser[] public tsBorrowers;

  TestUser public tsLiquidator1;
  TestUser public tsLiquidator2;
  TestUser public tsLiquidator3;
  TestUser[] public tsLiquidators;

  TestUser public tsStaker1;
  TestUser public tsStaker2;
  TestUser public tsStaker3;
  TestUser[] public tsStakers;

  TestUser public tsHacker1;
  TestUser[] public tsHackers;

  uint256[] public tsD1TokenIds;
  uint256[] public tsD2TokenIds;
  uint256[] public tsD3TokenIds;
  uint256[] public tsB1TokenIds;
  uint256[] public tsB2TokenIds;
  uint256[] public tsB3TokenIds;

  function setUp() public {
    tsDeployer = address(this);
    tsAclAdmin = makeAddr('tsAclAdmin');
    tsPoolAdmin = makeAddr('tsPoolAdmin');
    tsEmergencyAdmin = makeAddr('tsEmergencyAdmin');
    tsOracleAdmin = makeAddr('tsOracleAdmin');
    tsTreasury = makeAddr('tsTreasury');

    initTokens();

    initOracles();

    initContracts();

    initUsers();

    setContractsLabels();

    onSetUp();
  }

  function onSetUp() public virtual {}

  function initContracts() internal {
    /// Deploy proxies ///
    tsProxyAdmin = new ProxyAdmin();

    /// ACL Manager
    ACLManager aclManagerImpl = new ACLManager();
    TransparentUpgradeableProxy aclManagerProxy = new TransparentUpgradeableProxy(
      address(aclManagerImpl),
      address(tsProxyAdmin),
      abi.encodeWithSelector(aclManagerImpl.initialize.selector, tsAclAdmin)
    );
    tsAclManager = ACLManager(payable(address(aclManagerProxy)));
    //tsAclManager.initialize(aclAdmin);

    /// Price Oracle
    PriceOracle priceOracleImpl = new PriceOracle();
    TransparentUpgradeableProxy priceOracleProxy = new TransparentUpgradeableProxy(
      address(priceOracleImpl),
      address(tsProxyAdmin),
      abi.encodeWithSelector(
        priceOracleImpl.initialize.selector,
        address(tsAclManager),
        address(0),
        1e8,
        address(tsWETH),
        1e18
      )
    );
    tsPriceOracle = PriceOracle(payable(address(priceOracleProxy)));
    //tsPriceOracle.initialize(address(aclManager), address(0), 1e8, address(tsWETH), 1e18);

    // Pool Manager
    PoolManager poolManagerImpl = new PoolManager();
    TransparentUpgradeableProxy poolManagerProxy = new TransparentUpgradeableProxy(
      address(poolManagerImpl),
      address(tsProxyAdmin),
      abi.encodeWithSelector(
        poolManagerImpl.initialize.selector,
        address(tsWETH),
        address(tsAclManager),
        address(tsPriceOracle),
        tsTreasury
      )
    );
    tsPoolManager = PoolManager(payable(address(poolManagerProxy)));
    //tsPoolManager.initialize(address(tsWETH), address(aclManager), address(tsPriceOracle), tsTreasury);

    // Interest Rate Model
    tsYieldRateIRM = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (2 * WadRayMath.RAY) / 100,
      (1 * WadRayMath.RAY) / 100,
      (20 * WadRayMath.RAY) / 100
    );
    tsMiddleRateIRM = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    tsLowRateIRM = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (10 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    tsHighRateIRM = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (15 * WadRayMath.RAY) / 100,
      (8 * WadRayMath.RAY) / 100,
      (200 * WadRayMath.RAY) / 100
    );

    // set acl mananger
    tsHEVM.startPrank(tsAclAdmin);
    tsAclManager.addPoolAdmin(tsPoolAdmin);
    tsAclManager.addEmergencyAdmin(tsEmergencyAdmin);
    tsAclManager.addOracleAdmin(tsOracleAdmin);
    tsHEVM.stopPrank();

    // set price oracle
    tsHEVM.startPrank(tsOracleAdmin);
    tsPriceOracle.setBendNFTOracle(address(tsBendNFTOracle));

    address[] memory oracleAssets = new address[](3);
    oracleAssets[0] = address(tsWETH);
    oracleAssets[1] = address(tsDAI);
    oracleAssets[2] = address(tsUSDT);
    address[] memory oracleAggs = new address[](3);
    oracleAggs[0] = address(tsCLAggregatorWETH);
    oracleAggs[1] = address(tsCLAggregatorDAI);
    oracleAggs[2] = address(tsCLAggregatorUSDT);
    tsPriceOracle.setAssetChainlinkAggregators(oracleAssets, oracleAggs);
    tsHEVM.stopPrank();
  }

  function initTokens() internal {
    tsFaucet = new MockFaucet();

    tsWETH = MockERC20(tsFaucet.createMockERC20('MockWETH', 'WETH', 18));
    tsDAI = MockERC20(tsFaucet.createMockERC20('MockDAI', 'DAI', 18));
    tsUSDT = MockERC20(tsFaucet.createMockERC20('MockUSDT', 'USDT', 6));

    tsWPUNK = MockERC721(tsFaucet.createMockERC721('MockWPUNK', 'WPUNK'));
    tsBAYC = MockERC721(tsFaucet.createMockERC721('MockBAYC', 'BAYC'));
    tsMAYC = MockERC721(tsFaucet.createMockERC721('MockMAYC', 'MAYC'));
  }

  function initUsers() internal {
    uint256 baseUid;

    // depositors
    baseUid = 1;
    for (uint256 i = 0; i < 3; i++) {
      uint256 uid = ((i + 1) * 100);
      tsDepositors.push(new TestUser(tsPoolManager, uid));
      tsHEVM.label(address(tsDepositors[i]), string(abi.encodePacked('Depositor', Strings.toString(i + baseUid))));
      fillUserBalances(tsDepositors[i]);
    }
    tsDepositor1 = tsDepositors[0];
    tsDepositor2 = tsDepositors[1];
    tsDepositor3 = tsDepositors[2];

    // borrowers
    baseUid += 3;
    for (uint256 i = 0; i < 3; i++) {
      uint256 uid = ((i + baseUid) * 100);
      tsBorrowers.push(new TestUser(tsPoolManager, uid));
      tsHEVM.label(address(tsBorrowers[i]), string(abi.encodePacked('Borrower', Strings.toString(i + baseUid))));
      fillUserBalances(tsBorrowers[i]);
    }
    tsBorrower1 = tsBorrowers[0];
    tsBorrower2 = tsBorrowers[1];
    tsBorrower3 = tsBorrowers[2];

    // liquidators
    baseUid += 3;
    for (uint256 i = 0; i < 3; i++) {
      uint256 uid = ((i + baseUid) * 100);
      tsLiquidators.push(new TestUser(tsPoolManager, uid));
      tsHEVM.label(address(tsLiquidators[i]), string(abi.encodePacked('Liquidator', Strings.toString(i + baseUid))));
      fillUserBalances(tsLiquidators[i]);
    }
    tsLiquidator1 = tsLiquidators[0];
    tsLiquidator2 = tsLiquidators[1];
    tsLiquidator3 = tsLiquidators[2];

    // stakers
    baseUid += 3;
    for (uint256 i = 0; i < 3; i++) {
      uint256 uid = ((i + baseUid) * 100);
      tsStakers.push(new TestUser(tsPoolManager, uid));
      tsHEVM.label(address(tsStakers[i]), string(abi.encodePacked('Staker', Strings.toString(i + baseUid))));
      fillUserBalances(tsStakers[i]);
    }
    tsStaker1 = tsStakers[0];
    tsStaker2 = tsStakers[1];
    tsStaker3 = tsStakers[2];

    // hackers
    baseUid += 3;
    for (uint256 i = 0; i < 1; i++) {
      uint256 uid = ((i + baseUid) * 100);
      tsHackers.push(new TestUser(tsPoolManager, uid));
      tsHEVM.label(address(tsHackers[i]), string(abi.encodePacked('Hacker', Strings.toString(i + baseUid))));
      fillUserBalances(tsHackers[i]);
    }
    tsHacker1 = tsHackers[0];
  }

  function fillUserBalances(TestUser user) internal {
    tsHEVM.deal(address(user), 2_000_000 ether);

    tsHEVM.prank(address(user));
    IWETH(address(tsWETH)).deposit{value: TS_INITIAL_BALANCE * 1e18}();
    //tsFaucet.privateMintERC20(address(tsWETH), address(user), TS_INITIAL_BALANCE * 1e18);

    tsFaucet.privateMintERC20(address(tsDAI), address(user), TS_INITIAL_BALANCE * 1e18);
    tsFaucet.privateMintERC20(address(tsUSDT), address(user), TS_INITIAL_BALANCE * 1e6);

    uint256[] memory tokenIds = user.getTokenIds();
    tsFaucet.privateMintERC721(address(tsWPUNK), address(user), tokenIds);
    tsFaucet.privateMintERC721(address(tsBAYC), address(user), tokenIds);
    tsFaucet.privateMintERC721(address(tsMAYC), address(user), tokenIds);
  }

  function initOracles() internal {
    tsCLAggregatorWETH = new MockChainlinkAggregator(8, 'ETH / USD');
    tsHEVM.label(address(tsCLAggregatorWETH), 'MockCLAggregator(ETH/USD)');
    tsCLAggregatorWETH.updateAnswer(206066569863);

    tsCLAggregatorDAI = new MockChainlinkAggregator(8, 'DAI / USD');
    tsHEVM.label(address(tsCLAggregatorDAI), 'MockCLAggregator(DAI/USD)');
    tsCLAggregatorDAI.updateAnswer(99984627);

    tsCLAggregatorUSDT = new MockChainlinkAggregator(8, 'USDT / USD');
    tsHEVM.label(address(tsCLAggregatorUSDT), 'MockCLAggregator(USDT/USD)');
    tsCLAggregatorUSDT.updateAnswer(100053000);

    tsBendNFTOracle = new MockBendNFTOracle();
    tsHEVM.label(address(tsBendNFTOracle), 'MockBendNFTOracle');
    tsBendNFTOracle.setAssetPrice(address(tsWPUNK), 58155486904761904761);
    tsBendNFTOracle.setAssetPrice(address(tsBAYC), 30919141261229331011);
    tsBendNFTOracle.setAssetPrice(address(tsMAYC), 5950381013403414953);
  }

  function setContractsLabels() internal {
    tsHEVM.label(address(tsWETH), 'WETH');
    tsHEVM.label(address(tsDAI), 'DAI');
    tsHEVM.label(address(tsUSDT), 'USDT');
    tsHEVM.label(address(tsWPUNK), 'WPUNK');
    tsHEVM.label(address(tsBAYC), 'BAYC');
    tsHEVM.label(address(tsMAYC), 'MAYC');

    tsHEVM.label(address(tsAclManager), 'AclManager');
    tsHEVM.label(address(tsPriceOracle), 'PriceOracle');
    tsHEVM.label(address(tsPoolManager), 'PoolManager');

    tsHEVM.label(address(tsLowRateIRM), 'LowRiskIRM');
    tsHEVM.label(address(tsHighRateIRM), 'HighRiskIRM');
  }

  function initCommonPools() internal {
    tsHEVM.startPrank(tsPoolAdmin);

    tsCommonPoolId = tsPoolManager.createPool('Common Pool');

    tsLowRateGroupId = 1;
    tsMiddleRateGroupId = 2;
    tsHighRateGroupId = 3;
    tsPoolManager.addPoolGroup(tsCommonPoolId, tsLowRateGroupId);
    tsPoolManager.addPoolGroup(tsCommonPoolId, tsMiddleRateGroupId);
    tsPoolManager.addPoolGroup(tsCommonPoolId, tsHighRateGroupId);

    // asset some erc20 assets
    tsPoolManager.addAssetERC20(tsCommonPoolId, address(tsWETH));
    tsPoolManager.setAssetCollateralParams(tsCommonPoolId, address(tsWETH), 8050, 8300, 500);
    tsPoolManager.setAssetProtocolFee(tsCommonPoolId, address(tsWETH), 2000);
    tsPoolManager.setAssetClassGroup(tsCommonPoolId, address(tsWETH), tsLowRateGroupId);
    tsPoolManager.setAssetActive(tsCommonPoolId, address(tsWETH), true);
    tsPoolManager.setAssetBorrowing(tsCommonPoolId, address(tsWETH), true);

    tsPoolManager.addAssetERC20(tsCommonPoolId, address(tsDAI));
    tsPoolManager.setAssetCollateralParams(tsCommonPoolId, address(tsDAI), 7700, 8000, 500);
    tsPoolManager.setAssetProtocolFee(tsCommonPoolId, address(tsDAI), 2000);
    tsPoolManager.setAssetClassGroup(tsCommonPoolId, address(tsDAI), tsLowRateGroupId);
    tsPoolManager.setAssetActive(tsCommonPoolId, address(tsDAI), true);
    tsPoolManager.setAssetBorrowing(tsCommonPoolId, address(tsDAI), true);

    tsPoolManager.addAssetERC20(tsCommonPoolId, address(tsUSDT));
    tsPoolManager.setAssetCollateralParams(tsCommonPoolId, address(tsUSDT), 7400, 7600, 450);
    tsPoolManager.setAssetProtocolFee(tsCommonPoolId, address(tsUSDT), 2000);
    tsPoolManager.setAssetClassGroup(tsCommonPoolId, address(tsUSDT), tsLowRateGroupId);
    tsPoolManager.setAssetActive(tsCommonPoolId, address(tsUSDT), true);
    tsPoolManager.setAssetBorrowing(tsCommonPoolId, address(tsUSDT), true);

    // add interest group to assets
    tsPoolManager.addAssetGroup(tsCommonPoolId, address(tsWETH), tsLowRateGroupId, address(tsLowRateIRM));
    tsPoolManager.addAssetGroup(tsCommonPoolId, address(tsWETH), tsHighRateGroupId, address(tsHighRateIRM));

    tsPoolManager.addAssetGroup(tsCommonPoolId, address(tsDAI), tsLowRateGroupId, address(tsLowRateIRM));
    tsPoolManager.addAssetGroup(tsCommonPoolId, address(tsDAI), tsHighRateGroupId, address(tsHighRateIRM));

    tsPoolManager.addAssetGroup(tsCommonPoolId, address(tsUSDT), tsLowRateGroupId, address(tsLowRateIRM));
    tsPoolManager.addAssetGroup(tsCommonPoolId, address(tsUSDT), tsHighRateGroupId, address(tsHighRateIRM));

    // add some nft assets
    tsPoolManager.addAssetERC721(tsCommonPoolId, address(tsWPUNK));
    tsPoolManager.setAssetCollateralParams(tsCommonPoolId, address(tsWPUNK), 6000, 8000, 1000);
    tsPoolManager.setAssetAuctionParams(tsCommonPoolId, address(tsWPUNK), 5000, 500, 2000, 1 days);
    tsPoolManager.setAssetClassGroup(tsCommonPoolId, address(tsWPUNK), tsLowRateGroupId);
    tsPoolManager.setAssetActive(tsCommonPoolId, address(tsWPUNK), true);

    tsPoolManager.addAssetERC721(tsCommonPoolId, address(tsBAYC));
    tsPoolManager.setAssetCollateralParams(tsCommonPoolId, address(tsBAYC), 6000, 8000, 1000);
    tsPoolManager.setAssetAuctionParams(tsCommonPoolId, address(tsBAYC), 5000, 500, 2000, 1 days);
    tsPoolManager.setAssetClassGroup(tsCommonPoolId, address(tsBAYC), tsLowRateGroupId);
    tsPoolManager.setAssetActive(tsCommonPoolId, address(tsBAYC), true);

    tsPoolManager.addAssetERC721(tsCommonPoolId, address(tsMAYC));
    tsPoolManager.setAssetCollateralParams(tsCommonPoolId, address(tsMAYC), 5000, 8000, 1000);
    tsPoolManager.setAssetAuctionParams(tsCommonPoolId, address(tsMAYC), 5000, 500, 2000, 1 days);
    tsPoolManager.setAssetClassGroup(tsCommonPoolId, address(tsMAYC), tsHighRateGroupId);
    tsPoolManager.setAssetActive(tsCommonPoolId, address(tsMAYC), true);

    // yield
    tsPoolManager.setPoolYieldEnable(tsCommonPoolId, true);

    tsPoolManager.setAssetYieldEnable(tsCommonPoolId, address(tsWETH), true);
    tsPoolManager.setAssetYieldCap(tsCommonPoolId, address(tsWETH), 2000);
    tsPoolManager.setAssetYieldRate(tsCommonPoolId, address(tsWETH), address(tsYieldRateIRM));
    tsPoolManager.setStakerYieldCap(tsCommonPoolId, address(tsPoolManager), address(tsWETH), 2000);
    tsPoolManager.setStakerYieldCap(tsCommonPoolId, address(tsStaker1), address(tsWETH), 2000);

    tsPoolManager.setAssetYieldEnable(tsCommonPoolId, address(tsDAI), true);
    tsPoolManager.setAssetYieldCap(tsCommonPoolId, address(tsDAI), 2000);
    tsPoolManager.setAssetYieldRate(tsCommonPoolId, address(tsDAI), address(tsYieldRateIRM));
    tsPoolManager.setStakerYieldCap(tsCommonPoolId, address(tsPoolManager), address(tsDAI), 2000);
    tsPoolManager.setStakerYieldCap(tsCommonPoolId, address(tsStaker2), address(tsDAI), 2000);

    tsHEVM.stopPrank();
  }
}
