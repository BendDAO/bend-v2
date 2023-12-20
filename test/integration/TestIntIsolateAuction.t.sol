// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';
import 'src/libraries/helpers/Errors.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithIsolateAction.sol';

contract TestIntIsolateAuction is TestWithIsolateAction {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  function prepareUSDT(TestUser user) internal {
    uint256 depositAmount = 500_000 * (10 ** tsUSDT.decimals());
    user.approveERC20(address(tsUSDT), type(uint256).max);
    user.depositERC20(tsCommonPoolId, address(tsUSDT), depositAmount);
  }

  function prepareBAYC(TestUser user) internal returns (uint256[] memory tokenIds) {
    tokenIds = user.getTokenIds();
    user.setApprovalForAllERC721(address(tsBAYC), true);
    user.depositERC721(tsCommonPoolId, address(tsBAYC), tokenIds, Constants.SUPPLY_MODE_ISOLATE);
  }

  function prepareBorrow(TestUser user, address nftAsset, uint256[] memory tokenIds, address debtAsset) internal {
    TestLoanData memory loanDataBeforeBorrow = getIsolateCollateralData(tsCommonPoolId, nftAsset, 0, debtAsset);

    uint256[] memory borrowAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      borrowAmounts[i] = loanDataBeforeBorrow.availableBorrow - (i + 1);
    }

    user.isolateBorrow(tsCommonPoolId, nftAsset, tokenIds, debtAsset, borrowAmounts);
  }

  function test_RevertIf_AuctionUSDT() public {
    prepareUSDT(tsDepositor1);
    uint256[] memory tokenIds = prepareBAYC(tsBorrower1);
    prepareBorrow(tsBorrower1, address(tsBAYC), tokenIds, address(tsUSDT));

    // make some interest
    advanceTimes(365 days);

    // auction at first
    TestLoanData[] memory loanDataBeforeRepay = getIsolateLoanData(tsCommonPoolId, address(tsBAYC), tokenIds);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      assertGt(loanDataBeforeRepay[i].healthFactor, 1e18, 'healthFactor GT 1');
    }

    uint256[] memory bidAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bidAmounts[i] = loanDataBeforeRepay[i].borrowAmount;
    }

    tsHEVM.expectRevert(bytes(Errors.ISOLATE_BORROW_NOT_EXCEED_LIQUIDATION_THRESHOLD));
    tsLiquidator1.isolateAuction(tsCommonPoolId, address(tsBAYC), tokenIds, address(tsUSDT), bidAmounts);
  }

  function test_Should_AuctionUSDT_First() public {
    prepareUSDT(tsDepositor1);
    uint256[] memory tokenIds = prepareBAYC(tsBorrower1);
    prepareBorrow(tsBorrower1, address(tsBAYC), tokenIds, address(tsUSDT));

    // make some interest
    advanceTimes(365 days);

    // drop down nft price
    actionSetNftPrice(address(tsBAYC), 5000);

    TestLoanData[] memory loanDataBeforeRepay = getIsolateLoanData(tsCommonPoolId, address(tsBAYC), tokenIds);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      assertLt(loanDataBeforeRepay[i].healthFactor, 1e18, 'healthFactor not lt 1');
    }

    // auction at first
    if (_debugFlag) console.log('<<<<isolateAuction-1st-begin');
    uint256[] memory bidAmounts1 = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bidAmounts1[i] = loanDataBeforeRepay[i].borrowAmount;
    }

    tsLiquidator1.approveERC20(address(tsUSDT), type(uint256).max);
    tsLiquidator1.isolateAuction(tsCommonPoolId, address(tsBAYC), tokenIds, address(tsUSDT), bidAmounts1);
    if (_debugFlag) console.log('>>>>isolateAuction-1st-end');

    // auction at second
    if (_debugFlag) console.log('<<<<isolateAuction-2nd-begin');
    uint256[] memory bidAmounts2 = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bidAmounts2[i] = (bidAmounts1[i] * 1011) / 1000; // plus 1.1%
    }

    tsLiquidator2.approveERC20(address(tsUSDT), type(uint256).max);
    tsLiquidator2.isolateAuction(tsCommonPoolId, address(tsBAYC), tokenIds, address(tsUSDT), bidAmounts2);
    if (_debugFlag) console.log('>>>>isolateAuction-2nd-end');

    // auction at third
    if (_debugFlag) console.log('<<<<isolateAuction-3rd-begin');
    uint256[] memory bidAmounts3 = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bidAmounts3[i] = (bidAmounts2[i] * 1011) / 1000; // plus 1.1%
    }

    tsLiquidator3.approveERC20(address(tsUSDT), type(uint256).max);
    tsLiquidator3.isolateAuction(tsCommonPoolId, address(tsBAYC), tokenIds, address(tsUSDT), bidAmounts3);
    if (_debugFlag) console.log('>>>>isolateAuction-3rd-end');
  }
}
