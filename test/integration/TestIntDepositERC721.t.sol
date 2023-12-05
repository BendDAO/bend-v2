// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import './TestWithIntegration.sol';

contract TestIntDepositERC721 is TestWithIntegration {
  function onSetUp() public virtual override {
    super.onSetUp();
  }

  function test_RevertIf_ApproveNotEnough() public {
    uint256[] memory tokenIds = tsDepositor1.getTokenIds();

    tsDepositor1.setApprovalForAllERC721(address(tsBAYC), false);

    tsDepositor1.depositERC721(tsCommonPoolId, address(tsBAYC), tokenIds, Constants.SUPPLY_MODE_CROSS);
  }

  function test_Should_Deposit_BAYC() public {
    uint256[] memory tokenIds = tsDepositor1.getTokenIds();

    tsDepositor1.setApprovalForAllERC721(address(tsBAYC), true);

    tsDepositor1.depositERC721(tsCommonPoolId, address(tsBAYC), tokenIds, Constants.SUPPLY_MODE_CROSS);
  }
}
