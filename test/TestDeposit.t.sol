// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import './setup/TestSetup.sol';

contract TestDeposit is TestSetup {
  function testDeposit1() public {
    uint256 amount = 100 ether;

    depositor1.approve(address(weth), amount);

    depositor1.depositERC20(1, address(weth), amount);
  }
}
