// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import 'test/helpers/TestUser.sol';
import 'test/setup/TestWithCrossAction.sol';

contract TestIntCrossLiquidateERC721 is TestWithCrossAction {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  function test_Should_RepayUSDT_HasBAYC() public {
    prepareUSDT(tsDepositor1);

    uint256[] memory depTokenIds = prepareCrossBAYC(tsBorrower1);

    TestUserAccountData memory accountDataBeforeBorrow = getUserAccountData(tsCommonPoolId, address(tsBorrower1));

    // borrow some eth
    uint8[] memory borrowGroups = new uint8[](1);
    borrowGroups[0] = tsLowRateGroupId;

    uint256[] memory borrowAmounts = new uint256[](1);
    borrowAmounts[0] =
      (accountDataBeforeBorrow.availableBorrowInBase * (10 ** tsUSDT.decimals())) /
      tsPriceOracle.getAssetPrice(address(tsUSDT));
    borrowAmounts[0] + 10000000;

    actionCrossBorrowERC20(
      address(tsBorrower1),
      tsCommonPoolId,
      address(tsUSDT),
      borrowGroups,
      borrowAmounts,
      new bytes(0)
    );

    // make some interest
    advanceTimes(365 days);

    // drop down price and lower heath factor
    uint256 baycCurPrice = tsBendNFTOracle.getAssetPrice(address(tsBAYC));
    uint256 baycNewPrice = (baycCurPrice * 80) / 100;
    tsBendNFTOracle.setAssetPrice(address(tsBAYC), baycNewPrice);

    TestUserAccountData memory accountDataAfterBorrow = getUserAccountData(tsCommonPoolId, address(tsBorrower1));
    assertLt(accountDataAfterBorrow.healthFactor, 1e18, 'ACC:healthFactor');

    // liquidate some eth
    tsLiquidator1.approveERC20(address(tsUSDT), type(uint256).max);

    uint256[] memory liqTokenIds = new uint256[](1);
    liqTokenIds[0] = depTokenIds[0];

    actionCrossLiquidateERC721(
      address(tsLiquidator1),
      tsCommonPoolId,
      address(tsBorrower1),
      address(tsBAYC),
      liqTokenIds,
      address(tsUSDT),
      false,
      new bytes(0)
    );
  }
}