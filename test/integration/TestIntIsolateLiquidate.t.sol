// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';
import 'src/libraries/helpers/Errors.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithIsolateAction.sol';

contract TestIntIsolateLiquidate is TestWithIsolateAction {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  function prepareBorrow(TestUser user, address nftAsset, uint256[] memory tokenIds, address debtAsset) internal {
    TestLoanData memory loanDataBeforeBorrow = getIsolateCollateralData(tsCommonPoolId, nftAsset, 0, debtAsset);

    uint256[] memory borrowAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      borrowAmounts[i] = loanDataBeforeBorrow.availableBorrow - (i + 1);
    }

    user.isolateBorrow(tsCommonPoolId, nftAsset, tokenIds, debtAsset, borrowAmounts);
  }

  function prepareAuction(TestUser user, address nftAsset, uint256[] memory tokenIds, address debtAsset) internal {
    user.approveERC20(debtAsset, type(uint256).max);

    uint256[] memory bidAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      TestLoanData memory loanDataBeforeAuction = getIsolateLoanData(tsCommonPoolId, nftAsset, tokenIds[i]);
      assertLt(loanDataBeforeAuction.healthFactor, 1e18, 'healthFactor not lt 1');
      bidAmounts[i] = (loanDataBeforeAuction.borrowAmount * 1011) / 1000;
    }

    user.isolateAuction(tsCommonPoolId, nftAsset, tokenIds, debtAsset, bidAmounts);
  }

  function test_Should_LiquidateUSDT() public {
    // deposit
    prepareUSDT(tsDepositor1);
    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    // borrow
    prepareBorrow(tsBorrower1, address(tsBAYC), tokenIds, address(tsUSDT));

    // make some interest
    advanceTimes(365 days);

    // drop down nft price
    actionSetNftPrice(address(tsBAYC), 5000);

    // auction
    prepareAuction(tsLiquidator1, address(tsBAYC), tokenIds, address(tsUSDT));

    // end the auction
    advanceTimes(25 hours);

    // liquidate
    tsLiquidator1.isolateLiquidate(tsCommonPoolId, address(tsBAYC), tokenIds, address(tsUSDT), false);
  }
}
