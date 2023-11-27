// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import './IntegrationTest.sol';

import 'src/libraries/helpers/Constants.sol';

contract TestIntegrationBorrow is IntegrationTest {
  function onSetUp() public virtual override {
    super.onSetUp();

    uint256 wethAmount = 100 ether;
    tsDepositor1.approveERC20(address(tsWETH), wethAmount);
    tsDepositor1.depositERC20(tsCommonPoolId, address(tsWETH), wethAmount);

    uint256 usdtAmount = 100_000 * (10 ** tsUSDT.decimals());
    tsDepositor1.approveERC20(address(tsUSDT), usdtAmount);
    tsDepositor1.depositERC20(tsCommonPoolId, address(tsUSDT), usdtAmount);

    uint256 daiAmount = 100_000 * (10 ** tsDAI.decimals());
    tsDepositor1.approveERC20(address(tsDAI), daiAmount);
    tsDepositor1.depositERC20(tsCommonPoolId, address(tsDAI), daiAmount);
  }

  function testShouldBorrowUSDTWhenHasETH() public {
    uint256 wethAmount = 10 ether;
    tsBorrower1.approveERC20(address(tsWETH), wethAmount);
    tsBorrower1.depositERC20(tsCommonPoolId, address(tsWETH), wethAmount);

    uint256 usdtAmount = 1000 * (10 ** tsUSDT.decimals());
    tsBorrower1.borrowERC20(tsCommonPoolId, address(tsUSDT), tsLowRateGroupId, usdtAmount);
  }

  function testShouldBorrowERC20WhenHasERC721() public {
    tsBorrower1.setApprovalForAllERC721(address(tsBAYC));
    tsBorrower1.depositERC721(tsCommonPoolId, address(tsBAYC), tsBorrower1.getTokenIds(), Constants.SUPPLY_MODE_CROSS);

    tsBorrower1.borrowERC20(tsCommonPoolId, address(tsWETH), tsLowRateGroupId, 10 ether);
  }
}
