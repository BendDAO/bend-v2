// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import './TestWithIntegration.sol';

import 'src/libraries/helpers/Constants.sol';

contract TestIntCrossBorrowERC20 is TestWithIntegration {
  function onSetUp() public virtual override {
    super.onSetUp();
  }

  function testShouldBorrowUSDTWhenHasETH() public {
    uint256 wethAmount = 10 ether;
    tsBorrower1.approveERC20(address(tsWETH), wethAmount);

    uint256 usdtAmount = 1000 * (10 ** tsUSDT.decimals());
  }

  function testShouldBorrowERC20WhenHasERC721() public {
    tsBorrower1.setApprovalForAllERC721(address(tsBAYC), true);
  }
}
