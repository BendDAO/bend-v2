// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithIsolateAction.sol';

contract TestIntIsolateBorrow is TestWithIsolateAction {
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
    uint256 depositAmount = 500 ether;
    user.approveERC20(address(tsWETH), type(uint256).max);
    user.depositERC20(tsCommonPoolId, address(tsWETH), depositAmount);
  }

  function prepareBAYC(TestUser user) internal returns (uint256[] memory tokenIds) {
    tokenIds = user.getTokenIds();
    user.setApprovalForAllERC721(address(tsBAYC), true);
    user.depositERC721(tsCommonPoolId, address(tsBAYC), tokenIds, Constants.SUPPLY_MODE_ISOLATE);
  }

  function test_Should_BorrowUSDT_HasBAYC_Full() public {
    prepareUSDT(tsDepositor1);

    uint256[] memory tokenIds = prepareBAYC(tsBorrower1);

    // borrow full
    TestLoanData memory loanDataBeforeBorrow = getIsolateCollateralData(
      tsCommonPoolId,
      address(tsBAYC),
      0,
      address(tsUSDT)
    );

    uint256[] memory borrowAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      borrowAmounts[i] = loanDataBeforeBorrow.availableBorrow;
    }

    actionIsolateBorrow(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsBAYC),
      tokenIds,
      address(tsUSDT),
      borrowAmounts,
      new bytes(0)
    );
  }

  function test_Should_BorrowUSDT_HasBAYC_More() public {
    prepareUSDT(tsDepositor1);

    uint256[] memory tokenIds = prepareBAYC(tsBorrower1);

    // borrow part
    uint256[] memory borrowAmounts1 = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      TestLoanData memory loanDataBeforeBorrow1 = getIsolateCollateralData(
        tsCommonPoolId,
        address(tsBAYC),
        tokenIds[i],
        address(tsUSDT)
      );
      borrowAmounts1[i] = (loanDataBeforeBorrow1.availableBorrow * 50) / 100;
    }

    actionIsolateBorrow(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsBAYC),
      tokenIds,
      address(tsUSDT),
      borrowAmounts1,
      new bytes(0)
    );

    // borrow more
    uint256[] memory borrowAmounts2 = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      TestLoanData memory loanDataBeforeBorrow2 = getIsolateCollateralData(
        tsCommonPoolId,
        address(tsBAYC),
        tokenIds[i],
        address(tsUSDT)
      );
      borrowAmounts2[i] = loanDataBeforeBorrow2.availableBorrow - 1;
    }

    actionIsolateBorrow(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsBAYC),
      tokenIds,
      address(tsUSDT),
      borrowAmounts2,
      new bytes(0)
    );
  }

  function test_Should_BorrowWETH_HasBAYC_Full() public {
    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareBAYC(tsBorrower1);

    // borrow full
    TestLoanData memory loanDataBeforeBorrow = getIsolateCollateralData(
      tsCommonPoolId,
      address(tsBAYC),
      0,
      address(tsWETH)
    );

    uint256[] memory borrowAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      borrowAmounts[i] = loanDataBeforeBorrow.availableBorrow;
    }

    actionIsolateBorrow(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsBAYC),
      tokenIds,
      address(tsWETH),
      borrowAmounts,
      new bytes(0)
    );
  }

  function test_Should_BorrowWETH_HasBAYC_More() public {
    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareBAYC(tsBorrower1);

    // borrow part
    uint256[] memory borrowAmounts1 = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      TestLoanData memory loanDataBeforeBorrow1 = getIsolateCollateralData(
        tsCommonPoolId,
        address(tsBAYC),
        tokenIds[i],
        address(tsWETH)
      );
      borrowAmounts1[i] = (loanDataBeforeBorrow1.availableBorrow * 50) / 100;
    }

    actionIsolateBorrow(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsBAYC),
      tokenIds,
      address(tsWETH),
      borrowAmounts1,
      new bytes(0)
    );

    // borrow more
    uint256[] memory borrowAmounts2 = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      TestLoanData memory loanDataBeforeBorrow2 = getIsolateCollateralData(
        tsCommonPoolId,
        address(tsBAYC),
        tokenIds[i],
        address(tsWETH)
      );
      borrowAmounts2[i] = loanDataBeforeBorrow2.availableBorrow - 1;
    }

    actionIsolateBorrow(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsBAYC),
      tokenIds,
      address(tsWETH),
      borrowAmounts2,
      new bytes(0)
    );
  }
}
