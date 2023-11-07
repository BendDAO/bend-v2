// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ACLManager} from 'src/ACLManager.sol';
import {PriceOracle} from 'src/PriceOracle.sol';
import {DefaultInterestRateModel} from 'src/DefaultInterestRateModel.sol';
import {PoolManager} from 'src/PoolManager.sol';

import {MockERC20} from 'src/mocks/MockERC20.sol';

import {User} from '../helpers/User.sol';
import {Utils} from './Utils.sol';

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

contract TestSetup is Utils {
  Vm public hevm = Vm(HEVM_ADDRESS);

  uint256 public constant INITIAL_BALANCE = 1_000_000;

  address public deployer;
  address public aclAdmin;

  MockERC20 public weth;
  MockERC20 public dai;
  MockERC20 public usdt;

  ProxyAdmin public proxyAdmin;
  ACLManager public aclManager;
  PriceOracle public priceOracle;
  PoolManager public poolManager;

  User public depositor1;
  User public depositor2;
  User public depositor3;
  User[] public depositors;

  User public borrower1;
  User public borrower2;
  User public borrower3;
  User[] public borrowers;

  function setUp() public {
    deployer = address(this);
    aclAdmin = address(this);

    initContracts();

    initTokens();

    initUsers();

    setContractsLabels();

    onSetUp();
  }

  function onSetUp() public virtual {}

  function initContracts() internal {
    /// Deploy proxies ///
    proxyAdmin = new ProxyAdmin();

    /// ACL Manager
    ACLManager aclManagerImpl = new ACLManager();
    TransparentUpgradeableProxy aclManagerProxy = new TransparentUpgradeableProxy(
      address(aclManagerImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(aclManagerImpl.initialize.selector, aclAdmin)
    );
    aclManager = ACLManager(payable(address(aclManagerProxy)));
    //aclManager.initialize(aclAdmin);

    /// Price Oracle
    PriceOracle priceOracleImpl = new PriceOracle();
    TransparentUpgradeableProxy priceOracleProxy = new TransparentUpgradeableProxy(
      address(priceOracleImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(priceOracleImpl.initialize.selector, address(aclManager), address(0), 1e8)
    );
    priceOracle = PriceOracle(payable(address(priceOracleProxy)));
    //priceOracle.initialize(address(aclManager), address(0), 1e8);

    // Pool Manager
    PoolManager poolManagerImpl = new PoolManager();
    TransparentUpgradeableProxy poolManagerProxy = new TransparentUpgradeableProxy(
      address(poolManagerImpl),
      address(proxyAdmin),
      abi.encodeWithSelector(poolManagerImpl.initialize.selector, address(aclManager), address(priceOracle))
    );
    poolManager = PoolManager(payable(address(poolManagerProxy)));
    //poolManager.initialize(address(aclManager), address(priceOracle));
  }

  function initTokens() internal {
    weth = new MockERC20('MockWETH', 'WETH', 18);
    dai = new MockERC20('MockDAI', 'DAI', 18);
    usdt = new MockERC20('MockUSDT', 'USDT', 6);
  }

  function initUsers() internal {
    for (uint256 i = 0; i < 3; i++) {
      depositors.push(new User(poolManager));
      hevm.label(address(depositors[i]), string(abi.encodePacked('Depositor', Strings.toString(i + 1))));
      fillUserBalances(depositors[i]);
    }
    depositor1 = depositors[0];
    depositor2 = depositors[1];
    depositor3 = depositors[2];

    for (uint256 i = 0; i < 3; i++) {
      borrowers.push(new User(poolManager));
      hevm.label(address(borrowers[i]), string(abi.encodePacked('Borrower', Strings.toString(i + 1))));
      fillUserBalances(borrowers[i]);
    }

    borrower1 = borrowers[0];
    borrower2 = borrowers[1];
    borrower3 = borrowers[2];
  }

  function fillUserBalances(User _user) internal {
    weth.mintTo(address(_user), INITIAL_BALANCE * 1e18);
    dai.mintTo(address(_user), INITIAL_BALANCE * 1e18);
    usdt.mintTo(address(_user), INITIAL_BALANCE * 1e6);
  }

  function setContractsLabels() internal {
    hevm.label(address(weth), 'WETH');
    hevm.label(address(dai), 'DAI');
    hevm.label(address(usdt), 'USDT');

    hevm.label(address(aclManager), 'AclManager');
    hevm.label(address(priceOracle), 'PriceOracle');
    hevm.label(address(poolManager), 'PoolManager');
  }
}
