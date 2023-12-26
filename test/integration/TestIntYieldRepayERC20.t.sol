// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithBaseAction.sol';

contract TestIntYieldRepayERC20 is TestWithBaseAction {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  function prepareUSDT(TestUser user) internal {
    uint256 depositAmount = 500_000 * (10 ** tsUSDT.decimals());
    user.approveERC20(address(tsUSDT), type(uint256).max);
    user.depositERC20(tsCommonPoolId, address(tsUSDT), depositAmount);
  }

  function prepareWETH(TestUser user) internal {
    uint256 depositAmount = 100 ether;
    user.approveERC20(address(tsWETH), type(uint256).max);
    user.depositERC20(tsCommonPoolId, address(tsWETH), depositAmount);
  }

  function test_Should_RepayWETH() public {
    prepareWETH(tsDepositor1);

    uint256 borrowAmount = 10 ether;

    tsStaker1.yieldBorrowERC20(tsCommonPoolId, address(tsWETH), borrowAmount);

    // make some interest
    advanceTimes(365 days);

    // repay full
    uint256 repayAmount = tsPoolManager.getYieldERC20BorrowBalance(tsCommonPoolId, address(tsWETH), address(tsStaker1));
    assertGt(repayAmount, borrowAmount, 'yield balance should have interest');

    tsStaker1.approveERC20(address(tsWETH), type(uint256).max);

    tsStaker1.yieldRepayERC20(tsCommonPoolId, address(tsWETH), repayAmount);
  }
}
