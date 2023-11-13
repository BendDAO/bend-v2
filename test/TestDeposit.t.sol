// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import './setup/TestSetup.sol';

contract TestDeposit is TestSetup {
  function onSetUp() public virtual override {
    initCommonPools();
  }

  function testDeposit1() public {
    uint256 amount = 100 ether;

    tsDepositor1.approveERC20(address(tsWETH), amount);

    tsDepositor1.depositERC20(tsCommonPoolId, address(tsWETH), amount);
  }

  function testDeposit2() public {
    tsDepositor1.setApprovalForAllERC721(address(tsBAYC));

    tsDepositor1.depositERC721(
      tsCommonPoolId,
      address(tsBAYC),
      tsDepositor1.getTokenIds(),
      Constants.SUPPLY_MODE_CROSS
    );
  }
}
