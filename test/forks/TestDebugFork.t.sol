// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {PoolManager} from 'src/PoolManager.sol';
import {Installer} from 'src/modules/Installer.sol';
import {PoolLens} from 'src/modules/PoolLens.sol';

import '@forge-std/Test.sol';

// how to run this testcase
// forge test -vvv --match-contract TestDebugFork --fork-url https://eth-sepolia.g.alchemy.com/v2/{key} --fork-block-number {nnn}

contract TestDebugFork is Test {
  Vm public tsHEVM = Vm(HEVM_ADDRESS);
  PoolManager poolManager;
  Installer installer;

  function setUp() public {
    poolManager = PoolManager(payable(0xE16d9FB95eed698ee2384050a2C15BF1DdBA3E6C));
    installer = Installer(poolManager.moduleIdToProxy(Constants.MODULEID__INSTALLER));
  }

  function _testFork_Debug() public {
    bytes32 gitCommitHash;
    address[] memory modules = new address[](1);
    uint256 modIdx;

    PoolLens tsPoolLensImpl = new PoolLens(gitCommitHash);
    modules[modIdx++] = address(tsPoolLensImpl);

    tsHEVM.prank(0x99AcDAB13365e4CFcAa139A31de7CF8C80Ac5fb1);
    installer.installModules(modules);

    PoolLens poolLens = PoolLens(poolManager.moduleIdToProxy(Constants.MODULEID__POOL_LENS));
    poolLens.getUserAssetList(0xc24c9Af9007B8Eb713eFf069CDeC013DD86402E8, 1);
    poolLens.getUserAccountData(0xc24c9Af9007B8Eb713eFf069CDeC013DD86402E8, 1);
  }
}
