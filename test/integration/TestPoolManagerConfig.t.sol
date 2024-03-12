// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';

import {Errors} from 'src/libraries/helpers/Errors.sol';
import {PriceOracle} from 'src/PriceOracle.sol';

import 'test/mocks/MockERC20.sol';
import 'test/mocks/MockERC721.sol';
import 'test/mocks/MockChainlinkAggregator.sol';

import 'test/setup/TestWithSetup.sol';
import '@forge-std/Test.sol';

contract TestPoolManagerConfig is TestWithSetup {
  function onSetUp() public virtual override {
    super.onSetUp();
  }

  function test_RevertIf_CallerNotAdmin() public {
    tsHEVM.startPrank(address(tsHacker1));

    tsHEVM.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    tsPoolManager.createPool('test');

    tsHEVM.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    tsPoolManager.deletePool(1);

    tsHEVM.stopPrank();
  }

  // Global Configs
  function test_Should_ManagerGlobalStatus() public {
    tsHEVM.startPrank(address(tsEmergencyAdmin));

    tsPoolManager.setGlobalPause(true);

    bool isPaused1 = tsPoolManager.getGlobalPause();
    assertEq(isPaused1, true, 'isPaused1 not match');

    tsPoolManager.setGlobalPause(false);

    bool isPaused2 = tsPoolManager.getGlobalPause();
    assertEq(isPaused2, false, 'isPaused2 not match');

    tsHEVM.stopPrank();
  }

  // Pool Configs

  function test_Should_CreateAndDeletePool() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId1 = tsPoolManager.createPool('test 1');
    uint32 poolId2 = tsPoolManager.createPool('test 2');

    tsPoolManager.deletePool(poolId1);
    tsPoolManager.deletePool(poolId2);

    tsHEVM.stopPrank();
  }

  function test_Should_ManagerPoolStatus() public {
    tsHEVM.prank(address(tsPoolAdmin));
    uint32 poolId = tsPoolManager.createPool('test 1');

    tsHEVM.prank(address(tsEmergencyAdmin));
    tsPoolManager.setPoolPause(poolId, true);

    (bool isPaused1, , , ) = tsPoolManager.getPoolConfigFlag(poolId);
    assertEq(isPaused1, true, 'isPaused1 not match');

    tsHEVM.prank(address(tsEmergencyAdmin));
    tsPoolManager.setPoolPause(poolId, false);

    (bool isPaused2, , , ) = tsPoolManager.getPoolConfigFlag(poolId);
    assertEq(isPaused2, false, 'isPaused2 not match');
  }

  function test_Should_CreateAndDeletePoolGroup() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');

    tsPoolManager.addPoolGroup(poolId, 1);
    tsPoolManager.addPoolGroup(poolId, 2);
    tsPoolManager.addPoolGroup(poolId, 3);

    uint256[] memory retGroupIds1 = tsPoolManager.getPoolGroupList(poolId);
    assertEq(retGroupIds1.length, 3, 'retGroupIds1 length not match');
    assertEq(retGroupIds1[0], 1, 'retGroupIds1 index 0 not match');

    tsPoolManager.removePoolGroup(poolId, 1);
    tsPoolManager.removePoolGroup(poolId, 2);
    tsPoolManager.removePoolGroup(poolId, 3);

    uint256[] memory retGroupIds2 = tsPoolManager.getPoolGroupList(poolId);
    assertEq(retGroupIds2.length, 0, 'retGroupIds2 length not match');

    tsHEVM.stopPrank();
  }

  function test_RevertIf_DeletePoolGroupUsedByAsset() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');
    tsPoolManager.addPoolGroup(poolId, 1);
    tsPoolManager.addPoolGroup(poolId, 2);

    tsPoolManager.addAssetERC20(poolId, address(tsDAI));
    tsPoolManager.addAssetGroup(poolId, address(tsDAI), 1, address(tsLowRateIRM));

    tsHEVM.expectRevert(bytes(Errors.GROUP_USDED_BY_ASSET));
    tsPoolManager.removePoolGroup(poolId, 1);

    tsPoolManager.addAssetERC721(poolId, address(tsMAYC));
    tsPoolManager.setAssetClassGroup(poolId, address(tsMAYC), 2);

    tsHEVM.expectRevert(bytes(Errors.GROUP_USDED_BY_ASSET));
    tsPoolManager.removePoolGroup(poolId, 2);

    tsHEVM.stopPrank();
  }

  function test_Should_CreateAndDeleteAssetERC20() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');

    tsPoolManager.addAssetERC20(poolId, address(tsDAI));
    tsPoolManager.addAssetERC20(poolId, address(tsUSDT));
    tsPoolManager.addAssetERC20(poolId, address(tsWETH));

    address[] memory retAssets1 = tsPoolManager.getPoolAssetList(poolId);
    assertEq(retAssets1.length, 3, 'retAssets1 length not match');
    assertEq(retAssets1[0], address(tsDAI), 'retAssets1 index 0 not match');

    tsPoolManager.removeAssetERC20(poolId, address(tsDAI));
    tsPoolManager.removeAssetERC20(poolId, address(tsUSDT));
    tsPoolManager.removeAssetERC20(poolId, address(tsWETH));

    uint256[] memory retAssets2 = tsPoolManager.getPoolGroupList(poolId);
    assertEq(retAssets2.length, 0, 'retAssets2 length not match');

    tsHEVM.stopPrank();
  }

  function test_Should_CreateAndDeleteAssetERC721() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');

    tsPoolManager.addAssetERC721(poolId, address(tsWPUNK));
    tsPoolManager.addAssetERC721(poolId, address(tsBAYC));
    tsPoolManager.addAssetERC721(poolId, address(tsMAYC));

    address[] memory retAssets1 = tsPoolManager.getPoolAssetList(poolId);
    assertEq(retAssets1.length, 3, 'retAssets1 length not match');
    assertEq(retAssets1[0], address(tsWPUNK), 'retAssets1 index 0 not match');

    tsPoolManager.removeAssetERC721(poolId, address(tsWPUNK));
    tsPoolManager.removeAssetERC721(poolId, address(tsBAYC));
    tsPoolManager.removeAssetERC721(poolId, address(tsMAYC));

    uint256[] memory retAssets2 = tsPoolManager.getPoolGroupList(poolId);
    assertEq(retAssets2.length, 0, 'retAssets2 length not match');

    tsHEVM.stopPrank();
  }

  function test_Should_ManagePoolYield() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');

    tsPoolManager.setPoolYieldEnable(poolId, true);
    tsPoolManager.setPoolYieldPause(poolId, true);

    (, bool isYieldEnabled1, bool isYieldPaused1, ) = tsPoolManager.getPoolConfigFlag(poolId);
    assertEq(isYieldEnabled1, true, 'isYieldEnabled1 not match');
    assertEq(isYieldPaused1, true, 'isYieldPaused1 not match');

    tsPoolManager.setPoolYieldEnable(poolId, false);
    tsPoolManager.setPoolYieldPause(poolId, false);

    (, bool isYieldEnabled2, bool isYieldPaused2, ) = tsPoolManager.getPoolConfigFlag(poolId);
    assertEq(isYieldEnabled2, false, 'isYieldEnabled2 not match');
    assertEq(isYieldPaused2, false, 'isYieldPaused2 not match');

    tsHEVM.stopPrank();
  }

  // Asset Configs

  function test_Should_CreateAndDeleteAssetGroup() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');
    tsPoolManager.addPoolGroup(poolId, 1);
    tsPoolManager.addPoolGroup(poolId, 2);
    tsPoolManager.addPoolGroup(poolId, 3);

    tsPoolManager.addAssetERC20(poolId, address(tsWETH));

    tsPoolManager.addAssetGroup(poolId, address(tsWETH), 1, address(tsLowRateIRM));
    tsPoolManager.addAssetGroup(poolId, address(tsWETH), 2, address(tsMiddleRateIRM));
    tsPoolManager.addAssetGroup(poolId, address(tsWETH), 3, address(tsHighRateIRM));

    uint256[] memory retGroupIds1 = tsPoolManager.getAssetGroupList(poolId, address(tsWETH));
    assertEq(retGroupIds1.length, 3, 'retGroupIds1 length not match');
    assertEq(retGroupIds1[1], 2, 'retGroupIds1 index 1 not match');

    tsPoolManager.removeAssetGroup(poolId, address(tsWETH), 1);
    tsPoolManager.removeAssetGroup(poolId, address(tsWETH), 2);
    tsPoolManager.removeAssetGroup(poolId, address(tsWETH), 3);

    uint256[] memory retGroupIds2 = tsPoolManager.getAssetGroupList(poolId, address(tsWETH));
    assertEq(retGroupIds2.length, 0, 'retGroupIds1 length not match');

    tsHEVM.stopPrank();
  }

  function test_Should_ManagerAssetStatus() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');
    tsPoolManager.addAssetERC20(poolId, address(tsWETH));

    tsPoolManager.setAssetActive(poolId, address(tsWETH), true);
    tsPoolManager.setAssetFrozen(poolId, address(tsWETH), true);
    tsPoolManager.setAssetPause(poolId, address(tsWETH), true);

    (bool isActive1, bool isFrozen1, bool isPaused1, , , ) = tsPoolManager.getAssetConfigFlag(poolId, address(tsWETH));
    assertEq(isActive1, true, 'isActive1 not match');
    assertEq(isFrozen1, true, 'isFrozen1 not match');
    assertEq(isPaused1, true, 'isPaused1 not match');

    tsPoolManager.setAssetActive(poolId, address(tsWETH), false);
    tsPoolManager.setAssetFrozen(poolId, address(tsWETH), false);
    tsPoolManager.setAssetPause(poolId, address(tsWETH), false);

    (bool isActive2, bool isFrozen2, bool isPaused2, , , ) = tsPoolManager.getAssetConfigFlag(poolId, address(tsWETH));
    assertEq(isActive2, false, 'isActive2 not match');
    assertEq(isFrozen2, false, 'isFrozen2 not match');
    assertEq(isPaused2, false, 'isPaused2 not match');

    tsHEVM.stopPrank();
  }

  function test_Should_ManageAssetCap() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');
    tsPoolManager.addAssetERC20(poolId, address(tsWETH));

    tsPoolManager.setAssetSupplyCap(poolId, address(tsWETH), 220 ether);
    tsPoolManager.setAssetBorrowCap(poolId, address(tsWETH), 150 ether);
    tsPoolManager.setAssetYieldCap(poolId, address(tsWETH), 2000); // 20%

    (uint256 supplyCap1, uint256 borrowCap1, uint256 yieldCap1) = tsPoolManager.getAssetConfigCap(
      poolId,
      address(tsWETH)
    );
    assertEq(supplyCap1, 220 ether, 'supplyCap1 not match');
    assertEq(borrowCap1, 150 ether, 'borrowCap1 not match');
    assertEq(yieldCap1, 2000, 'yieldCap1 not match');

    tsPoolManager.setAssetSupplyCap(poolId, address(tsWETH), 0 ether);
    tsPoolManager.setAssetBorrowCap(poolId, address(tsWETH), 0 ether);
    tsPoolManager.setAssetYieldCap(poolId, address(tsWETH), 0); // 0%

    (uint256 supplyCap2, uint256 borrowCap2, uint256 yieldCap2) = tsPoolManager.getAssetConfigCap(
      poolId,
      address(tsWETH)
    );
    assertEq(supplyCap2, 0, 'supplyCap1 not match');
    assertEq(borrowCap2, 0, 'borrowCap1 not match');
    assertEq(yieldCap2, 0, 'yieldCap1 not match');

    tsHEVM.stopPrank();
  }

  function test_Should_ManageAssetClassGroupAndRate() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');
    tsPoolManager.addPoolGroup(poolId, 1);
    tsPoolManager.addPoolGroup(poolId, 2);

    tsPoolManager.addAssetERC20(poolId, address(tsWETH));
    tsPoolManager.addAssetGroup(poolId, address(tsWETH), 1, address(tsLowRateIRM));

    // test class group
    tsPoolManager.setAssetClassGroup(poolId, address(tsWETH), 1);

    (uint256 classGroup1, , , , ) = tsPoolManager.getAssetLendingConfig(poolId, address(tsWETH));
    assertEq(classGroup1, 1, 'classGroup1 not match');

    tsPoolManager.setAssetClassGroup(poolId, address(tsWETH), 2);

    (uint256 classGroup2, , , , ) = tsPoolManager.getAssetLendingConfig(poolId, address(tsWETH));
    assertEq(classGroup2, 2, 'classGroup1 not match');

    // test group rate
    tsPoolManager.setAssetLendingRate(poolId, address(tsWETH), 1, address(tsHighRateIRM));

    (, , , , , , address rateModel1) = tsPoolManager.getAssetGroupData(poolId, address(tsWETH), 1);
    assertEq(rateModel1, address(tsHighRateIRM), 'rateModel1 not match');

    tsHEVM.stopPrank();
  }

  function test_Should_ManageAssetYield() public {
    tsHEVM.startPrank(address(tsPoolAdmin));

    uint32 poolId = tsPoolManager.createPool('test 1');
    tsPoolManager.setPoolYieldEnable(poolId, true);
    tsPoolManager.addAssetERC20(poolId, address(tsWETH));

    tsPoolManager.setAssetYieldEnable(poolId, address(tsWETH), true);
    tsPoolManager.setAssetYieldPause(poolId, address(tsWETH), true);

    (, , , , bool isYieldEnabled1, bool isYieldPaused1) = tsPoolManager.getAssetConfigFlag(poolId, address(tsWETH));
    assertEq(isYieldEnabled1, true, 'isYieldEnabled1 not match');
    assertEq(isYieldPaused1, true, 'isYieldPaused1 not match');

    tsPoolManager.setAssetYieldEnable(poolId, address(tsWETH), false);
    tsPoolManager.setAssetYieldPause(poolId, address(tsWETH), false);

    (, , , , bool isYieldEnabled2, bool isYieldPaused2) = tsPoolManager.getAssetConfigFlag(poolId, address(tsWETH));
    assertEq(isYieldEnabled2, false, 'isYieldEnabled2 not match');
    assertEq(isYieldPaused2, false, 'isYieldPaused2 not match');

    tsHEVM.stopPrank();
  }
}
