// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {IInterestRateModel} from 'src/interfaces/IInterestRateModel.sol';

import {TestWithData} from './TestWithData.sol';

import 'forge-std/Test.sol';

abstract contract TestWithAction is TestWithData {
  using WadRayMath for uint256;

  enum TestAction {
    DepositERC20,
    WithdrawERC20,
    DepositERC721,
    WithdrawERC721,
    CrossBorrowERC20,
    CrossRepayERC20,
    CrossLiquidateERC20,
    CrossLiquidateERC721,
    IsolateBorrow,
    IsolateRepay,
    IsolateAuction,
    IsolateRedeem,
    IsolateLiquidate
  }

  function onSetUp() public virtual override {
    super.onSetUp();
  }

  /****************************************************************************/
  /* Actions */
  /****************************************************************************/

  function actionDepositERC20(
    address sender,
    uint32 poolId,
    address asset,
    uint256 amount,
    bytes memory revertMessage
  ) internal {
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.depositERC20(poolId, asset, amount);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      tsHEVM.prank(sender);
      tsPoolManager.depositERC20(poolId, asset, amount);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      TestContractData memory dataAfter = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // calc expected data
      TestAssetData memory expectedAssetData = calcExpectedAssetDataAfterDepositERC20(
        dataBefore,
        dataAfter,
        amount,
        txTimestamp
      );
      TestUserData memory expectedUserData = calcExpectedUserDataAfterDepositERC20(
        dataBefore,
        dataAfter,
        amount,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.DepositERC20, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.DepositERC20, dataAfter.userData, expectedUserData);
    }
  }

  function actionWithdrawERC20(
    address sender,
    uint32 poolId,
    address asset,
    uint256 amount,
    bytes memory revertMessage
  ) internal {
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.withdrawERC20(poolId, asset, amount);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      tsHEVM.prank(sender);
      tsPoolManager.withdrawERC20(poolId, asset, amount);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      TestContractData memory dataAfter = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // calc expected data
      TestAssetData memory expectedAssetData = calcExpectedAssetDataAfterWithdrawERC20(
        dataBefore,
        dataAfter,
        amount,
        txTimestamp
      );
      TestUserData memory expectedUserData = calcExpectedUserDataAfterWithdrawERC20(
        dataBefore,
        dataAfter,
        amount,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.WithdrawERC20, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.WithdrawERC20, dataAfter.userData, expectedUserData);
    }
  }

  function actionDepositERC721(
    address sender,
    uint32 poolId,
    address asset,
    uint256[] memory tokenIds,
    uint8 supplyMode,
    bytes memory revertMessage
  ) internal {
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.depositERC721(poolId, asset, tokenIds, supplyMode);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC721);

      // send tx
      tsHEVM.prank(sender);
      tsPoolManager.depositERC721(poolId, asset, tokenIds, supplyMode);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      TestContractData memory dataAfter = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC721);

      // calc expected data
      TestAssetData memory expectedAssetData = calcExpectedAssetDataAfterDepositERC721(
        dataBefore,
        dataAfter,
        tokenIds.length,
        txTimestamp
      );
      TestUserData memory expectedUserData = calcExpectedUserDataAfterDepositERC721(
        dataBefore,
        dataAfter,
        tokenIds.length,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.DepositERC721, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.DepositERC721, dataAfter.userData, expectedUserData);
    }
  }

  function actionWithdrawERC721(
    address sender,
    uint32 poolId,
    address asset,
    uint256[] memory tokenIds,
    uint8 supplyMode,
    bytes memory revertMessage
  ) internal {
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.withdrawERC721(poolId, asset, tokenIds, supplyMode);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      tsHEVM.prank(sender);
      tsPoolManager.withdrawERC721(poolId, asset, tokenIds, supplyMode);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      TestContractData memory dataAfter = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // calc expected data
      TestAssetData memory expectedAssetData = calcExpectedAssetDataAfterWithdrawERC721(
        dataBefore,
        dataAfter,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );
      TestUserData memory expectedUserData = calcExpectedUserDataAfterWithdrawERC721(
        dataBefore,
        dataAfter,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.WithdrawERC721, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.WithdrawERC721, dataAfter.userData, expectedUserData);
    }
  }

  /****************************************************************************/
  /* Checks */
  /****************************************************************************/
  function checkAssetData(
    TestAction /*action*/,
    TestAssetData memory afterAssetData,
    TestAssetData memory expectedAssetData
  ) internal {
    assertEq(afterAssetData.totalCrossSupply, expectedAssetData.totalCrossSupply, 'AD:totalCrossSupply');
    assertEq(afterAssetData.totalIsolateSupply, expectedAssetData.totalIsolateSupply, 'AD:totalIsolateSupply');
    assertEq(afterAssetData.availableSupply, expectedAssetData.availableSupply, 'AD:availableSupply');
    assertEq(afterAssetData.utilizationRate, expectedAssetData.utilizationRate, 'AD:utilizationRate');
  }

  function checkUserAssetData(
    TestAction /*action*/,
    TestUserData memory afterUserData,
    TestUserData memory expectedUserData
  ) internal {
    assertEq(
      afterUserData.userAssetData.walletBalance,
      expectedUserData.userAssetData.walletBalance,
      'UD:AD:walletBalance'
    );
    assertEq(
      afterUserData.userAssetData.totalCrossSupply,
      expectedUserData.userAssetData.totalCrossSupply,
      'UD:AD:totalCrossSupply'
    );
    assertEq(
      afterUserData.userAssetData.totalIsolateSupply,
      expectedUserData.userAssetData.totalIsolateSupply,
      'UD:AD:walletBalance'
    );
  }

  /****************************************************************************/
  /* Calculations */
  /****************************************************************************/

  /* DepositERC20 */
  function calcExpectedAssetDataAfterDepositERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountDeposited,
    uint256 txTimestamp
  ) internal view returns (TestAssetData memory expectedAssetData) {
    // supply
    expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply + amountDeposited;
    expectedAssetData.totalIsolateSupply = dataBefore.assetData.totalIsolateSupply;

    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply + amountDeposited;
    expectedAssetData.totalLiquidity = dataBefore.assetData.totalLiquidity + amountDeposited;

    expectedAssetData.supplyIndex = calcExpectedSupplyIndex(
      dataBefore.assetData.utilizationRate,
      dataBefore.assetData.supplyRate,
      dataBefore.assetData.supplyIndex,
      dataBefore.assetData.lastUpdateTimestamp,
      txTimestamp
    );

    // borrow
    expectedAssetData.totalCrossBorrow = dataBefore.assetData.totalCrossBorrow;
    expectedAssetData.totalIsolateBorrow = dataBefore.assetData.totalIsolateBorrow;

    expectedAssetData.utilizationRate = calcExpectedUtilizationRate(
      expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow,
      expectedAssetData.totalLiquidity
    );

    expectedAssetData.groupsData = new TestGroupData[](dataBefore.assetData.groupsData.length);
    for (uint256 i = 0; i < dataBefore.assetData.groupsData.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.assetData.groupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.assetData.groupsData[i].totalIsolateBorrow;
      expectedGroupData.borrowIndex = dataBefore.assetData.groupsData[i].borrowIndex;
    }

    // rate
    calcExpectedInterestRates(expectedAssetData);
  }

  function calcExpectedUserDataAfterDepositERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountDeposited,
    uint256 /*txTimestamp*/
  ) internal pure returns (TestUserData memory expectedUserData) {
    // supply
    expectedUserData.userAssetData.walletBalance = dataBefore.userData.userAssetData.walletBalance - amountDeposited;

    expectedUserData.userAssetData.totalCrossSupply =
      dataBefore.userData.userAssetData.totalCrossSupply +
      amountDeposited;
    expectedUserData.userAssetData.totalIsolateSupply = dataBefore.userData.userAssetData.totalIsolateSupply;

    // borrow
    expectedUserData.userAssetData.totalCrossBorrow = dataBefore.userData.userAssetData.totalCrossBorrow;
    expectedUserData.userAssetData.totalIsolateBorrow = dataBefore.userData.userAssetData.totalIsolateBorrow;

    expectedUserData.userGroupsData = new TestUserGroupData[](dataBefore.userData.userGroupsData.length);

    for (uint256 i = 0; i < dataBefore.userData.userGroupsData.length; i++) {
      TestUserGroupData memory expectedGroupData = expectedUserData.userGroupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.userData.userGroupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.userData.userGroupsData[i].totalIsolateBorrow;
    }
  }

  /* WithdrawERC20 */

  function calcExpectedAssetDataAfterWithdrawERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint256 txTimestamp
  ) internal view returns (TestAssetData memory expectedAssetData) {
    // supply
    expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply - amountWithdrawn;
    expectedAssetData.totalIsolateSupply = dataBefore.assetData.totalIsolateSupply;

    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - amountWithdrawn;
    expectedAssetData.totalLiquidity = dataBefore.assetData.totalLiquidity - amountWithdrawn;

    expectedAssetData.supplyIndex = calcExpectedSupplyIndex(
      dataBefore.assetData.utilizationRate,
      dataBefore.assetData.supplyRate,
      dataBefore.assetData.supplyIndex,
      dataBefore.assetData.lastUpdateTimestamp,
      txTimestamp
    );

    // borrow
    expectedAssetData.totalCrossBorrow = dataBefore.assetData.totalCrossBorrow;
    expectedAssetData.totalIsolateBorrow = dataBefore.assetData.totalIsolateBorrow;

    expectedAssetData.utilizationRate = calcExpectedUtilizationRate(
      expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow,
      expectedAssetData.totalLiquidity
    );

    expectedAssetData.groupsData = new TestGroupData[](dataBefore.assetData.groupsData.length);
    for (uint256 i = 0; i < dataBefore.assetData.groupsData.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.assetData.groupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.assetData.groupsData[i].totalIsolateBorrow;
      expectedGroupData.borrowIndex = dataBefore.assetData.groupsData[i].borrowIndex;
    }

    // rate
    calcExpectedInterestRates(expectedAssetData);
  }

  function calcExpectedUserDataAfterWithdrawERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint256 /*txTimestamp*/
  ) internal pure returns (TestUserData memory expectedUserData) {
    // supply
    expectedUserData.userAssetData.walletBalance = dataBefore.userData.userAssetData.walletBalance + amountWithdrawn;

    expectedUserData.userAssetData.totalCrossSupply =
      dataBefore.userData.userAssetData.totalCrossSupply -
      amountWithdrawn;
    expectedUserData.userAssetData.totalIsolateSupply = dataBefore.userData.userAssetData.totalIsolateSupply;

    // borrow
    expectedUserData.userAssetData.totalCrossBorrow = dataBefore.userData.userAssetData.totalCrossBorrow;
    expectedUserData.userAssetData.totalIsolateBorrow = dataBefore.userData.userAssetData.totalIsolateBorrow;

    expectedUserData.userGroupsData = new TestUserGroupData[](dataBefore.userData.userGroupsData.length);

    for (uint256 i = 0; i < dataBefore.userData.userGroupsData.length; i++) {
      TestUserGroupData memory expectedGroupData = expectedUserData.userGroupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.userData.userGroupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.userData.userGroupsData[i].totalIsolateBorrow;
    }
  }

  /* DepositERC721 */

  function calcExpectedAssetDataAfterDepositERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountDeposited,
    uint256 /*txTimestamp*/
  ) internal view returns (TestAssetData memory expectedAssetData) {
    // supply
    expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply + amountDeposited;
    expectedAssetData.totalIsolateSupply = dataBefore.assetData.totalIsolateSupply;

    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply + amountDeposited;
    expectedAssetData.totalLiquidity = dataBefore.assetData.totalLiquidity + amountDeposited;

    expectedAssetData.supplyIndex = dataBefore.assetData.supplyIndex;

    // borrow
    expectedAssetData.totalCrossBorrow = dataBefore.assetData.totalCrossBorrow;
    expectedAssetData.totalIsolateBorrow = dataBefore.assetData.totalIsolateBorrow;

    expectedAssetData.utilizationRate = dataBefore.assetData.utilizationRate;

    expectedAssetData.groupsData = new TestGroupData[](dataBefore.assetData.groupsData.length);
    for (uint256 i = 0; i < dataBefore.assetData.groupsData.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.assetData.groupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.assetData.groupsData[i].totalIsolateBorrow;
      expectedGroupData.borrowIndex = dataBefore.assetData.groupsData[i].borrowIndex;
    }

    // rate
    calcExpectedInterestRates(expectedAssetData);
  }

  function calcExpectedUserDataAfterDepositERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountDeposited,
    uint256 /*txTimestamp*/
  ) internal pure returns (TestUserData memory expectedUserData) {
    // supply
    expectedUserData.userAssetData.walletBalance = dataBefore.userData.userAssetData.walletBalance - amountDeposited;

    expectedUserData.userAssetData.totalCrossSupply =
      dataBefore.userData.userAssetData.totalCrossSupply +
      amountDeposited;
    expectedUserData.userAssetData.totalIsolateSupply = dataBefore.userData.userAssetData.totalIsolateSupply;

    // borrow
    expectedUserData.userAssetData.totalCrossBorrow = dataBefore.userData.userAssetData.totalCrossBorrow;
    expectedUserData.userAssetData.totalIsolateBorrow = dataBefore.userData.userAssetData.totalIsolateBorrow;

    expectedUserData.userGroupsData = new TestUserGroupData[](dataBefore.userData.userGroupsData.length);

    for (uint256 i = 0; i < dataBefore.userData.userGroupsData.length; i++) {
      TestUserGroupData memory expectedGroupData = expectedUserData.userGroupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.userData.userGroupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.userData.userGroupsData[i].totalIsolateBorrow;
    }
  }

  /* WithdrawERC721 */

  function calcExpectedAssetDataAfterWithdrawERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint8 supplyMode,
    uint256 txTimestamp
  ) internal view returns (TestAssetData memory expectedAssetData) {
    // supply
    if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply - amountWithdrawn;
      expectedAssetData.totalIsolateSupply = dataBefore.assetData.totalIsolateSupply;
    } else if (supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply;
      expectedAssetData.totalIsolateSupply = dataBefore.assetData.totalIsolateSupply - amountWithdrawn;
    }

    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - amountWithdrawn;
    expectedAssetData.totalLiquidity = dataBefore.assetData.totalLiquidity - amountWithdrawn;

    expectedAssetData.supplyIndex = dataBefore.assetData.supplyIndex;
    expectedAssetData.supplyRate = dataBefore.assetData.supplyRate;

    // borrow
    expectedAssetData.totalCrossBorrow = dataBefore.assetData.totalCrossBorrow;
    expectedAssetData.totalIsolateBorrow = dataBefore.assetData.totalIsolateBorrow;

    expectedAssetData.utilizationRate = dataBefore.assetData.utilizationRate;

    expectedAssetData.groupsData = new TestGroupData[](dataBefore.assetData.groupsData.length);
    for (uint256 i = 0; i < dataBefore.assetData.groupsData.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.assetData.groupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.assetData.groupsData[i].totalIsolateBorrow;
      expectedGroupData.borrowIndex = dataBefore.assetData.groupsData[i].borrowIndex;
      expectedGroupData.borrowRate = dataBefore.assetData.groupsData[i].borrowRate;
    }
  }

  function calcExpectedUserDataAfterWithdrawERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal pure returns (TestUserData memory expectedUserData) {
    // supply
    expectedUserData.userAssetData.walletBalance = dataBefore.userData.userAssetData.walletBalance + amountWithdrawn;

    if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedUserData.userAssetData.totalCrossSupply =
        dataBefore.userData.userAssetData.totalCrossSupply -
        amountWithdrawn;
      expectedUserData.userAssetData.totalIsolateSupply = dataBefore.userData.userAssetData.totalIsolateSupply;
    } else if (supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      expectedUserData.userAssetData.totalCrossSupply = dataBefore.userData.userAssetData.totalCrossSupply;
      expectedUserData.userAssetData.totalIsolateSupply =
        dataBefore.userData.userAssetData.totalIsolateSupply -
        amountWithdrawn;
    }

    // borrow
    expectedUserData.userAssetData.totalCrossBorrow = dataBefore.userData.userAssetData.totalCrossBorrow;
    expectedUserData.userAssetData.totalIsolateBorrow = dataBefore.userData.userAssetData.totalIsolateBorrow;

    expectedUserData.userGroupsData = new TestUserGroupData[](dataBefore.userData.userGroupsData.length);

    for (uint256 i = 0; i < dataBefore.userData.userGroupsData.length; i++) {
      TestUserGroupData memory expectedGroupData = expectedUserData.userGroupsData[i];
      expectedGroupData.totalCrossBorrow = dataBefore.userData.userGroupsData[i].totalCrossBorrow;
      expectedGroupData.totalIsolateBorrow = dataBefore.userData.userGroupsData[i].totalIsolateBorrow;
    }
  }

  /****************************************************************************/
  /* Helpers for Calculations */
  /****************************************************************************/

  function calcExpectedInterestRates(TestAssetData memory expectedAssetData) internal view {
    uint256 totalBorrowRate;
    uint256 totalBorrowInAsset = expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow;
    for (uint256 i = 0; i < expectedAssetData.groupsData.length; i++) {
      TestGroupData memory groupData = expectedAssetData.groupsData[i];
      uint256 totalBorrowInGroup = groupData.totalCrossBorrow + groupData.totalIsolateBorrow;
      if (totalBorrowInGroup > 0) {
        groupData.borrowRate = IInterestRateModel(groupData.rateModel).calculateGroupBorrowRate(
          expectedAssetData.utilizationRate
        );

        totalBorrowRate += (groupData.borrowRate * totalBorrowInGroup) / totalBorrowInAsset;
      }
    }

    expectedAssetData.supplyRate = totalBorrowRate * expectedAssetData.utilizationRate;
  }

  function calcExpectedUtilizationRate(uint256 totalBorrow, uint256 totalSupply) internal pure returns (uint256) {
    if (totalBorrow == 0) return 0;
    return totalBorrow.rayDiv(totalSupply);
  }

  function calcExpectedNormalizedIncome(
    uint256 supplyRate,
    uint256 supplyIndex,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    if (supplyRate == 0) return supplyIndex;

    uint256 cumulatedInterest = calcLinearInterest(supplyRate, lastUpdateTimestamp, currentTimestamp);
    return cumulatedInterest.rayMul(supplyIndex);
  }

  function calcExpectedNormalizedDebt(
    uint256 borrowRate,
    uint256 borrowIndex,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    if (borrowRate == 0) return borrowIndex;

    uint256 cumulatedInterest = calcCompoundedInterest(borrowRate, lastUpdateTimestamp, currentTimestamp);
    return cumulatedInterest.rayMul(borrowIndex);
  }

  function calcExpectedSupplyIndex(
    uint256 utilizationRate,
    uint256 supplyRate,
    uint256 supplyIndex,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    if (utilizationRate == 0) return supplyIndex;

    return calcExpectedNormalizedIncome(supplyRate, supplyIndex, lastUpdateTimestamp, currentTimestamp);
  }

  function calcExpectedBorrowIndex(
    uint256 totalBorrow,
    uint256 borrowRate,
    uint256 borrowIndex,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    if (totalBorrow == 0) return borrowIndex;

    return calcExpectedNormalizedDebt(borrowRate, borrowIndex, lastUpdateTimestamp, currentTimestamp);
  }

  function calcExpectedTotalBorrow(uint256 scaledBorrow, uint256 expectedBorrowIndex) internal pure returns (uint256) {
    return scaledBorrow.rayMul(expectedBorrowIndex);
  }

  function calcLinearInterest(
    uint256 rate,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    return MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp, currentTimestamp);
  }

  function calcCompoundedInterest(
    uint256 rate,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    return MathUtils.calculateCompoundedInterest(rate, lastUpdateTimestamp, currentTimestamp);
  }
}
