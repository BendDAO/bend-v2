// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import './setup/TestSetup.sol';

import 'src/libraries/helpers/Constants.sol';

contract TestBorrow is TestSetup {
  function onSetUp() public virtual override {
    initCommonPools();
  }

  function testBorrow1() public {
    uint256 amount = 100 ether;

    tsDepositor1.approveERC20(address(tsWETH), amount);
    tsDepositor1.depositERC20(tsCommonPoolId, address(tsWETH), amount);

    tsBorrower1.setApprovalForAllERC721(address(tsBAYC));
    tsBorrower1.depositERC721(tsCommonPoolId, address(tsBAYC), tsBorrower1.getTokenIds(), Constants.SUPPLY_MODE_CROSS);

    tsBorrower1.borrowERC20(tsCommonPoolId, address(tsWETH), tsLowRiskGroupId, 10 ether, address(this));
  }
}
