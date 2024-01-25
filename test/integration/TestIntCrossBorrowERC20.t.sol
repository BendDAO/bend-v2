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

    prepareCrossBAYC(tsBorrower1);

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

  function test_Should_BorrowUSDT_HasWETH_BAYC() public {
    prepareUSDT(tsDepositor1);
    prepareUSDT(tsDepositor2);

    prepareWETH(tsBorrower1);
    prepareCrossBAYC(tsBorrower1);

    ( 
      ,
      ,
      uint256[] memory groupsAvailableBorrowInBase
    ) = tsPoolManager.getUserAccountDebtData(address(tsBorrower1), tsCommonPoolId);

    uint256 groupNum = 0;
    for (uint256 groupId=0; groupId<groupsAvailableBorrowInBase.length; groupId++) {
      if (groupsAvailableBorrowInBase[groupId] > 0) {
        groupNum++;
      }
    }

    uint256 usdtPrice = tsPriceOracle.getAssetPrice(address(tsUSDT));

    uint8[] memory borrowGroups = new uint8[](groupNum);
    uint256[] memory borrowAmounts = new uint256[](1);

    uint256 grpIdx = 0;
    for (uint256 groupId=0; groupId<groupsAvailableBorrowInBase.length; groupId++) {
      if (groupsAvailableBorrowInBase[groupId] > 0) {
        borrowGroups[grpIdx] = uint8(groupId);
        borrowAmounts[grpIdx] = groupsAvailableBorrowInBase[groupId] * (10 ** tsUSDT.decimals()) / usdtPrice;
        grpIdx++;
      }
    }

    tsBorrower1.crossBorrowERC20(
      tsCommonPoolId,
      address(tsUSDT),
      borrowGroups,
      borrowAmounts
    );
  }
}
