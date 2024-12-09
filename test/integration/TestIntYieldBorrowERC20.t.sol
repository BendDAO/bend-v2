// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'src/libraries/helpers/Constants.sol';
import 'src/libraries/helpers/Errors.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithBaseAction.sol';

contract TestIntYieldBorrowERC20 is TestWithBaseAction {
  struct TestCaseVars {
    uint256 stakerCap;
    uint256 stakerBorrow;
    uint256 availableBorrow;
  }

  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  function test_Should_BorrowWETH() public {
    prepareWETH(tsDepositor1);

    uint256 borrowAmount = 10 ether;

    TestCaseVars memory varsBefore;
    (varsBefore.stakerCap, varsBefore.stakerBorrow, varsBefore.availableBorrow) = tsPoolLens.getYieldStakerAssetData(
      tsCommonPoolId,
      address(tsWETH),
      address(tsStaker1)
    );
    assertGt(varsBefore.stakerCap, borrowAmount, 'varsBefore.stakerCap');
    assertEq(varsBefore.stakerBorrow, 0, 'varsBefore.stakerBorrow');
    assertEq(varsBefore.availableBorrow, varsBefore.stakerCap, 'varsBefore.availableBorrow');

    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount);

    TestCaseVars memory varsAfter;
    (varsAfter.stakerCap, varsAfter.stakerBorrow, varsAfter.availableBorrow) = tsPoolLens.getYieldStakerAssetData(
      tsCommonPoolId,
      address(tsWETH),
      address(tsStaker1)
    );
    assertEq(varsAfter.stakerBorrow, borrowAmount, 'varsAfter.stakerBorrow');
    assertEq(varsAfter.availableBorrow, (varsAfter.stakerCap - borrowAmount), 'varsAfter.availableBorrow');
  }

  function test_ReverfIf_BorrowWETH_AssetYield_Disable() public {
    prepareWETH(tsDepositor1);

    tsHEVM.prank(tsPoolAdmin);
    tsConfigurator.setAssetYieldEnable(tsCommonPoolId, address(tsWETH), false);

    uint256 borrowAmount = 10 ether;
    tsHEVM.expectRevert(bytes(Errors.ASSET_YIELD_NOT_ENABLE));
    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount);
  }

  function test_ReverfIf_BorrowWETH_Invalid_Staker_CapZero() public {
    prepareWETH(tsDepositor1);

    tsHEVM.prank(tsPoolAdmin);
    tsConfigurator.setManagerYieldCap(tsCommonPoolId, address(tsStaker1), address(tsWETH), 0);

    uint256 borrowAmount = 10 ether;
    tsHEVM.expectRevert(bytes(Errors.YIELD_EXCEED_STAKER_CAP_LIMIT));
    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount);
  }

  function test_ReverfIf_BorrowWETH_Exceed_StakerYieldCap() public {
    prepareWETH(tsDepositor1);

    tsHEVM.prank(tsPoolAdmin);
    tsConfigurator.setManagerYieldCap(tsCommonPoolId, address(tsStaker1), address(tsWETH), 100); // 1%

    TestCaseVars memory varsBefore;
    (varsBefore.stakerCap, varsBefore.stakerBorrow, varsBefore.availableBorrow) = tsPoolLens.getYieldStakerAssetData(
      tsCommonPoolId,
      address(tsWETH),
      address(tsStaker1)
    );

    // borrow all available
    uint256 borrowAmount = varsBefore.availableBorrow;
    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount);

    // borrow more
    uint256 borrowAmount2 = 0.123 ether;
    tsHEVM.expectRevert(bytes(Errors.YIELD_EXCEED_STAKER_CAP_LIMIT));
    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount2);
  }

  function test_ReverfIf_BorrowWETH_Exceed_AssetYieldCap() public {
    prepareWETH(tsDepositor1);

    TestCaseVars memory varsBefore;
    (varsBefore.stakerCap, varsBefore.stakerBorrow, varsBefore.availableBorrow) = tsPoolLens.getYieldStakerAssetData(
      tsCommonPoolId,
      address(tsWETH),
      address(tsStaker1)
    );

    // borrow all available
    uint256 borrowAmount = varsBefore.availableBorrow;
    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount);

    // borrow more
    uint256 borrowAmount2 = 0.123 ether;
    tsHEVM.expectRevert(bytes(Errors.YIELD_EXCEED_ASSET_CAP_LIMIT));
    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount2);
  }
}
