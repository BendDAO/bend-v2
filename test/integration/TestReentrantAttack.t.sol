// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'src/libraries/helpers/Constants.sol';
import 'src/libraries/helpers/Errors.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithBaseAction.sol';

contract TestReentrantAttack is TestWithBaseAction {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  function test_RevertIf_CrossLiquidateERC721() public {
    prepareUSDT(tsDepositor1);

    uint256[] memory depTokenIds = prepareCrossBAYC(tsBorrower1);

    TestUserAccountData memory accountDataBeforeBorrow = getUserAccountData(address(tsBorrower1), tsCommonPoolId);

    // borrow some eth
    uint8[] memory borrowGroups = new uint8[](1);
    borrowGroups[0] = tsLowRateGroupId;

    uint256[] memory borrowAmounts = new uint256[](1);
    borrowAmounts[0] =
      (accountDataBeforeBorrow.availableBorrowInBase * (10 ** tsUSDT.decimals())) /
      tsPriceOracle.getAssetPrice(address(tsUSDT));

    tsBorrower1.crossBorrowERC20(
      tsCommonPoolId,
      address(tsUSDT),
      borrowGroups,
      borrowAmounts,
      address(tsBorrower1),
      address(tsBorrower1)
    );

    // make some interest
    advanceTimes(365 days);

    // drop down price and lower heath factor
    uint256 baycCurPrice = tsBendNFTOracle.getAssetPrice(address(tsBAYC));
    uint256 baycNewPrice = (baycCurPrice * 75) / 100;
    tsBendNFTOracle.setAssetPrice(address(tsBAYC), baycNewPrice);

    // liquidate some eth
    tsLiquidator1.approveERC20(address(tsUSDT), type(uint256).max);

    uint256[] memory liqTokenIds = new uint256[](1);
    liqTokenIds[0] = depTokenIds[0];

    uint256[] memory attackTypes = tsLiquidator1.getReentrantAttackTypes();
    for (uint i = 0; i < attackTypes.length; i++) {
      tsLiquidator1.setAttackType(attackTypes[i]);

      tsHEVM.expectRevert(bytes(Errors.REENTRANCY_ALREADY_LOCKED));
      tsLiquidator1.crossLiquidateERC721(
        tsCommonPoolId,
        address(tsBorrower1),
        address(tsBAYC),
        liqTokenIds,
        address(tsUSDT),
        false
      );
    }
  }

  function prepareBorrow(TestUser user, address nftAsset, uint256[] memory tokenIds, address debtAsset) internal {
    TestLoanData memory loanDataBeforeBorrow = getIsolateCollateralData(tsCommonPoolId, nftAsset, 0, debtAsset);

    uint256[] memory borrowAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      borrowAmounts[i] = loanDataBeforeBorrow.availableBorrow - (i + 1);
    }

    user.isolateBorrow(tsCommonPoolId, nftAsset, tokenIds, debtAsset, borrowAmounts, address(user), address(user));
  }

  function prepareAuction(TestUser user, address nftAsset, uint256[] memory tokenIds, address debtAsset) internal {
    user.approveERC20(debtAsset, type(uint256).max);

    uint256[] memory bidAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      TestLoanData memory loanDataBeforeAuction = getIsolateLoanData(tsCommonPoolId, nftAsset, tokenIds[i]);
      assertLt(loanDataBeforeAuction.healthFactor, 1e18, 'healthFactor not lt 1');
      bidAmounts[i] = (loanDataBeforeAuction.borrowAmount * 1011) / 1000;

      (uint256 borrowAmount /*uint256 thresholdPrice*/, , uint256 liquidatePrice) = tsPoolLens.getIsolateLiquidateData(
        tsCommonPoolId,
        address(tsBAYC),
        tokenIds[i]
      );
      assertLe(borrowAmount, liquidatePrice, 'borrowAmount not le liquidatePrice');
    }

    user.isolateAuction(tsCommonPoolId, nftAsset, tokenIds, debtAsset, bidAmounts);
  }

  function test_RevertIf_IsolateLiquidate() public {
    // deposit
    prepareWETH(tsDepositor1);
    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    // borrow
    prepareBorrow(tsBorrower1, address(tsBAYC), tokenIds, address(tsWETH));

    // make some interest
    advanceTimes(365 days);

    // drop down nft price
    actionSetNftPrice(address(tsBAYC), 5000);

    // auction
    prepareAuction(tsLiquidator1, address(tsBAYC), tokenIds, address(tsWETH));

    // end the auction
    advanceTimes(25 hours);

    uint256[] memory liquidateAmounts = new uint256[](tokenIds.length);

    uint256[] memory attackTypes = tsLiquidator1.getReentrantAttackTypes();
    for (uint i = 0; i < attackTypes.length; i++) {
      tsLiquidator1.setAttackType(attackTypes[i]);

      tsHEVM.expectRevert(bytes(Errors.REENTRANCY_ALREADY_LOCKED));
      tsLiquidator1.isolateLiquidate(
        tsCommonPoolId,
        address(tsBAYC),
        tokenIds,
        address(tsWETH),
        liquidateAmounts,
        false
      );
    }
  }
}
