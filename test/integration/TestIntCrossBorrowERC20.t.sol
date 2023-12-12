// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithCrossAction.sol';

contract TestIntCrossBorrowERC20 is TestWithCrossAction {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  function prepareUSDT(TestUser user) internal {
    uint256 depositAmount = 100_000 * (10 ** tsUSDT.decimals());
    user.approveERC20(address(tsUSDT), type(uint256).max);
    user.depositERC20(tsCommonPoolId, address(tsUSDT), depositAmount);
  }

  function prepareWETH(TestUser user) internal {
    uint256 depositAmount = 10 ether;
    user.approveERC20(address(tsWETH), type(uint256).max);
    user.depositERC20(tsCommonPoolId, address(tsWETH), depositAmount);
  }

  function prepareBAYC(TestUser user) internal {
    uint256[] memory tokenIds = user.getTokenIds();
    user.setApprovalForAllERC721(address(tsBAYC), true);
    user.depositERC721(tsCommonPoolId, address(tsBAYC), tokenIds, Constants.SUPPLY_MODE_CROSS);
  }

  function test_Should_BorrowUSDT_HasWETH() public {
    prepareUSDT(tsDepositor1);

    prepareWETH(tsBorrower1);

    uint8[] memory borrowGroups = new uint8[](1);
    borrowGroups[0] = tsLowRateGroupId;

    uint256[] memory borrowAmounts = new uint256[](1);
    borrowAmounts[0] = 1000 * (10 ** tsUSDT.decimals());

    actionCrossBorrowERC20(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsUSDT),
      borrowGroups,
      borrowAmounts,
      new bytes(0)
    );
  }

  function test_Should_BorrowUSDT_HasBAYC() public {
    prepareUSDT(tsDepositor1);

    prepareBAYC(tsBorrower1);

    uint8[] memory borrowGroups = new uint8[](1);
    borrowGroups[0] = tsLowRateGroupId;

    uint256[] memory borrowAmounts = new uint256[](1);
    borrowAmounts[0] = 1000 * (10 ** tsUSDT.decimals());

    actionCrossBorrowERC20(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsUSDT),
      borrowGroups,
      borrowAmounts,
      new bytes(0)
    );
  }
}
