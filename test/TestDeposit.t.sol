// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import './setup/TestSetup.sol';

contract TestDeposit is TestSetup {
  function onSetUp() public virtual override {
    initCommonPools();
  }

  function testDeposit1() public {
    uint256 amount = 100 ether;

    tsDepositor1.approve(address(tsWETH), amount);

    tsDepositor1.depositERC20(tsCommonPoolId, address(tsWETH), amount);
  }
}
