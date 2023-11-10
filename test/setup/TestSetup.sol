// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

import {ACLManager} from 'src/ACLManager.sol';
import {PriceOracle} from 'src/PriceOracle.sol';
import {DefaultInterestRateModel} from 'src/DefaultInterestRateModel.sol';
import {PoolManager} from 'src/PoolManager.sol';

import {MockERC20} from 'test/mocks/MockERC20.sol';
import {MockERC721} from 'test/mocks/MockERC721.sol';
import {MockFaucet} from 'test/mocks/MockFaucet.sol';

import {TestUser} from '../helpers/TestUser.sol';
import {TestUtils} from './TestUtils.sol';

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

contract TestSetup is TestUtils {
  Vm public tsHEVM = Vm(HEVM_ADDRESS);

  uint256 public constant TS_INITIAL_BALANCE = 1_000_000;

  address public tsDeployer;
  address public tsAclAdmin;

  MockFaucet public tsFaucet;
  MockERC20 public tsWETH;
  MockERC20 public tsDAI;
  MockERC20 public tsUSDT;
  MockERC721 public tsBAYC;
  MockERC721 public tsMAYC;

  ProxyAdmin public tsProxyAdmin;
  ACLManager public tsAclManager;
  PriceOracle public tsPriceOracle;
  PoolManager public tsPoolManager;

  uint32 public tsCommonPoolId;
  DefaultInterestRateModel public tsLowRiskIRM;
  DefaultInterestRateModel public tsHighRiskIRM;

  TestUser public tsDepositor1;
  TestUser public tsDepositor2;
  TestUser public tsDepositor3;
  TestUser[] public tsDepositors;

  TestUser public tsBorrower1;
  TestUser public tsBorrower2;
  TestUser public tsBorrower3;
  TestUser[] public tsBorrowers;

  uint256[] public tsD1TokenIds;
  uint256[] public tsD2TokenIds;
  uint256[] public tsD3TokenIds;
  uint256[] public tsB1TokenIds;
  uint256[] public tsB2TokenIds;
  uint256[] public tsB3TokenIds;

  function setUp() public {
    tsDeployer = address(this);
    tsAclAdmin = address(this);

    initContracts();

    initTokens();

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
      abi.encodeWithSelector(priceOracleImpl.initialize.selector, address(tsAclManager), address(0), 1e8)
    );
    tsPriceOracle = PriceOracle(payable(address(priceOracleProxy)));
    //tsPriceOracle.initialize(address(aclManager), address(0), 1e8);

    // Pool Manager
    PoolManager poolManagerImpl = new PoolManager();
    TransparentUpgradeableProxy poolManagerProxy = new TransparentUpgradeableProxy(
      address(poolManagerImpl),
      address(tsProxyAdmin),
      abi.encodeWithSelector(poolManagerImpl.initialize.selector, address(tsAclManager), address(tsPriceOracle))
    );
    tsPoolManager = PoolManager(payable(address(poolManagerProxy)));
    //tsPoolManager.initialize(address(aclManager), address(tsPriceOracle));

    // Interest Rate Model
    tsLowRiskIRM = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (10 * WadRayMath.RAY) / 100,
      (5 * WadRayMath.RAY) / 100,
      (100 * WadRayMath.RAY) / 100
    );
    tsHighRiskIRM = new DefaultInterestRateModel(
      (65 * WadRayMath.RAY) / 100,
      (15 * WadRayMath.RAY) / 100,
      (8 * WadRayMath.RAY) / 100,
      (200 * WadRayMath.RAY) / 100
    );
  }

  function initTokens() internal {
    tsFaucet = new MockFaucet();

    tsWETH = MockERC20(tsFaucet.createMockERC20('MockWETH', 'WETH', 18));
    tsDAI = MockERC20(tsFaucet.createMockERC20('MockDAI', 'DAI', 18));
    tsUSDT = MockERC20(tsFaucet.createMockERC20('MockUSDT', 'USDT', 6));

    tsBAYC = MockERC721(tsFaucet.createMockERC721('MockBAYC', 'BAYC'));
    tsMAYC = MockERC721(tsFaucet.createMockERC721('MockMAYC', 'MAYC'));
  }

  function initUsers() internal {
    for (uint256 i = 0; i < 3; i++) {
      uint256 uid = ((i + 1) * 100);
      tsDepositors.push(new TestUser(tsPoolManager, uid));
      tsHEVM.label(address(tsDepositors[i]), string(abi.encodePacked('Depositor', Strings.toString(i + 1))));
      fillUserBalances(tsDepositors[i]);
    }
    tsDepositor1 = tsDepositors[0];
    tsDepositor2 = tsDepositors[1];
    tsDepositor3 = tsDepositors[2];

    for (uint256 i = 0; i < 3; i++) {
      uint256 uid = ((i + 4) * 100);
      tsBorrowers.push(new TestUser(tsPoolManager, uid));
      tsHEVM.label(address(tsBorrowers[i]), string(abi.encodePacked('Borrower', Strings.toString(i + 4))));
      fillUserBalances(tsBorrowers[i]);
    }

    tsBorrower1 = tsBorrowers[0];
    tsBorrower2 = tsBorrowers[1];
    tsBorrower3 = tsBorrowers[2];
  }

  function fillUserBalances(TestUser user) internal {
    tsFaucet.privateMintERC20(address(tsWETH), address(user), TS_INITIAL_BALANCE * 1e18);
    tsFaucet.privateMintERC20(address(tsDAI), address(user), TS_INITIAL_BALANCE * 1e18);
    tsFaucet.privateMintERC20(address(tsUSDT), address(user), TS_INITIAL_BALANCE * 1e6);

    uint256[] memory tokenIds = user.getTokenIds();
    tsFaucet.privateMintERC721(address(tsBAYC), address(user), tokenIds);
    tsFaucet.privateMintERC721(address(tsMAYC), address(user), tokenIds);
  }

  function setContractsLabels() internal {
    tsHEVM.label(address(tsWETH), 'WETH');
    tsHEVM.label(address(tsDAI), 'DAI');
    tsHEVM.label(address(tsUSDT), 'USDT');
    tsHEVM.label(address(tsBAYC), 'BAYC');
    tsHEVM.label(address(tsMAYC), 'MAYC');

    tsHEVM.label(address(tsAclManager), 'AclManager');
    tsHEVM.label(address(tsPriceOracle), 'PriceOracle');
    tsHEVM.label(address(tsPoolManager), 'PoolManager');

    tsHEVM.label(address(tsLowRiskIRM), 'LowRiskIRM');
    tsHEVM.label(address(tsHighRiskIRM), 'HighRiskIRM');
  }

  function initCommonPools() internal {
    tsCommonPoolId = tsPoolManager.createPool();
    tsPoolManager.addAssetERC20(tsCommonPoolId, address(tsWETH), 1);
    tsPoolManager.addAssetERC20(tsCommonPoolId, address(tsDAI), 1);
    tsPoolManager.addAssetERC20(tsCommonPoolId, address(tsUSDT), 1);

    tsPoolManager.addGroup(tsCommonPoolId, address(tsWETH), address(tsLowRiskIRM));
    tsPoolManager.addGroup(tsCommonPoolId, address(tsWETH), address(tsHighRiskIRM));

    tsPoolManager.addGroup(tsCommonPoolId, address(tsDAI), address(tsLowRiskIRM));
    tsPoolManager.addGroup(tsCommonPoolId, address(tsDAI), address(tsHighRiskIRM));

    tsPoolManager.addGroup(tsCommonPoolId, address(tsUSDT), address(tsLowRiskIRM));
    tsPoolManager.addGroup(tsCommonPoolId, address(tsUSDT), address(tsHighRiskIRM));

    tsPoolManager.addAssetERC721(tsCommonPoolId, address(tsBAYC), 1);
    tsPoolManager.addAssetERC721(tsCommonPoolId, address(tsMAYC), 2);
  }
}
