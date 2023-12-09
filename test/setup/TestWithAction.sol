// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import {IInterestRateModel} from 'src/interfaces/IInterestRateModel.sol';

import {TestWithData} from './TestWithData.sol';

import 'forge-std/Test.sol';

abstract contract TestWithAction is TestWithData {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

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

  // Supply

  function actionDepositERC20(
    address sender,
    uint32 poolId,
    address asset,
    uint256 amount,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('<<<<actionDepositERC20', 'begin');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.depositERC20(poolId, asset, amount);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      if (_debugFlag) console.log('actionDepositERC20', 'sendtx');
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
      TestUserAssetData memory expectedUserData = calcExpectedUserDataAfterDepositERC20(
        dataBefore,
        dataAfter,
        amount,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.DepositERC20, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.DepositERC20, dataAfter.userAssetData, expectedUserData);
    }
    if (_debugFlag) console.log('>>>>actionDepositERC20', 'end');
  }

  function actionWithdrawERC20(
    address sender,
    uint32 poolId,
    address asset,
    uint256 amount,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('actionWithdrawERC20', 'begin');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.withdrawERC20(poolId, asset, amount);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      if (_debugFlag) console.log('actionWithdrawERC20', 'sendtx');
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
      TestUserAssetData memory expectedUserData = calcExpectedUserDataAfterWithdrawERC20(
        dataBefore,
        dataAfter,
        amount,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.WithdrawERC20, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.WithdrawERC20, dataAfter.userAssetData, expectedUserData);
    }
    if (_debugFlag) console.log('actionWithdrawERC20', 'end');
  }

  function actionDepositERC721(
    address sender,
    uint32 poolId,
    address asset,
    uint256[] memory tokenIds,
    uint8 supplyMode,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('actionDepositERC721', 'sendtx');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.depositERC721(poolId, asset, tokenIds, supplyMode);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC721);

      // send tx
      if (_debugFlag) console.log('actionDepositERC721', 'sendtx');
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
        supplyMode,
        txTimestamp
      );
      TestUserAssetData memory expectedUserData = calcExpectedUserDataAfterDepositERC721(
        dataBefore,
        dataAfter,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.DepositERC721, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.DepositERC721, dataAfter.userAssetData, expectedUserData);
    }
    if (_debugFlag) console.log('actionDepositERC721', 'end');
  }

  function actionWithdrawERC721(
    address sender,
    uint32 poolId,
    address asset,
    uint256[] memory tokenIds,
    uint8 supplyMode,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('actionWithdrawERC721', 'begin');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.withdrawERC721(poolId, asset, tokenIds, supplyMode);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      if (_debugFlag) console.log('actionWithdrawERC721', 'sendtx');
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
      TestUserAssetData memory expectedUserData = calcExpectedUserDataAfterWithdrawERC721(
        dataBefore,
        dataAfter,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.WithdrawERC721, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.WithdrawERC721, dataAfter.userAssetData, expectedUserData);
    }
    if (_debugFlag) console.log('actionWithdrawERC721', 'end');
  }

  // Cross Lending

  function actionCrossBorrowERC20(
    address sender,
    uint32 poolId,
    address asset,
    uint8[] memory groups,
    uint256[] memory amounts,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('<<<<actionCrossBorrowERC20', 'begin');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.crossBorrowERC20(poolId, asset, groups, amounts);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      if (_debugFlag) console.log('actionCrossBorrowERC20', 'sendtx');
      tsHEVM.prank(sender);
      tsPoolManager.crossBorrowERC20(poolId, asset, groups, amounts);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      TestContractData memory dataAfter = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // calc expected data
      TestAssetData memory expectedAssetData = calcExpectedAssetDataAfterCrossBorrowERC20(
        dataBefore,
        dataAfter,
        groups,
        amounts,
        txTimestamp
      );
      TestUserAssetData memory expectedUserData = calcExpectedUserDataAfterCrossBorrowERC20(
        dataBefore,
        dataAfter,
        groups,
        amounts,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.CrossBorrowERC20, dataAfter.assetData, expectedAssetData);
      checkUserAssetData(TestAction.CrossBorrowERC20, dataAfter.userAssetData, expectedUserData);
    }
    if (_debugFlag) console.log('>>>>actionCrossBorrowERC20', 'end');
  }

  function actionCrossRepayERC20(
    address sender,
    uint32 poolId,
    address asset,
    uint8[] memory groups,
    uint256[] memory amounts,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('<<<<actionCrossRepayERC20', 'begin');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.crossRepayERC20(poolId, asset, groups, amounts);
    } else {
      // fetch contract data
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // send tx
      if (_debugFlag) console.log('actionCrossRepayERC20', 'sendtx');
      tsHEVM.prank(sender);
      tsPoolManager.crossRepayERC20(poolId, asset, groups, amounts);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      TestContractData memory dataAfter = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC20);

      // calc expected data
      TestContractData memory dataExpected;

      calcExpectedAssetDataAfterCrossRepayERC20(dataBefore, dataAfter, dataExpected, groups, amounts, txTimestamp);
      calcExpectedUserDataAfterCrossRepayERC20(dataBefore, dataAfter, dataExpected, groups, amounts, txTimestamp);

      // check the results
      checkAssetData(TestAction.CrossRepayERC20, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.CrossRepayERC20, dataAfter.userAssetData, dataExpected.userAssetData);
    }
    if (_debugFlag) console.log('>>>>actionCrossRepayERC20', 'end');
  }

  // Isolate Lending

  // Yield

  /****************************************************************************/
  /* Checks */
  /****************************************************************************/
  function checkAssetData(
    TestAction /*action*/,
    TestAssetData memory afterAssetData,
    TestAssetData memory expectedAssetData
  ) internal {
    if (_debugFlag) console.log('checkAssetData', 'begin');
    assertEq(afterAssetData.totalCrossSupply, expectedAssetData.totalCrossSupply, 'AD:totalCrossSupply');
    assertEq(afterAssetData.totalIsolateSupply, expectedAssetData.totalIsolateSupply, 'AD:totalIsolateSupply');
    assertEq(afterAssetData.availableSupply, expectedAssetData.availableSupply, 'AD:availableSupply');
    assertEq(afterAssetData.utilizationRate, expectedAssetData.utilizationRate, 'AD:utilizationRate');

    assertEq(afterAssetData.supplyRate, expectedAssetData.supplyRate, 'AD:supplyRate');
    assertEq(afterAssetData.supplyIndex, expectedAssetData.supplyIndex, 'AD:supplyIndex');

    for (uint256 i = 0; i < afterAssetData.groupsData.length; i++) {
      if (_debugFlag) console.log('checkAssetData', 'group', i);
      TestGroupData memory afterGroupData = afterAssetData.groupsData[i];
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];

      assertEq(afterGroupData.totalCrossBorrow, expectedGroupData.totalCrossBorrow, 'AD:totalCrossBorrow');
      assertEq(afterGroupData.totalIsolateBorrow, expectedGroupData.totalIsolateBorrow, 'AD:totalIsolateBorrow');
      assertEq(afterGroupData.borrowRate, expectedGroupData.borrowRate, 'AD:borrowRate');
      assertEq(afterGroupData.borrowIndex, expectedGroupData.borrowIndex, 'AD:borrowIndex');
    }
    if (_debugFlag) console.log('checkAssetData', 'end');
  }

  function checkUserAssetData(
    TestAction /*action*/,
    TestUserAssetData memory afterUserData,
    TestUserAssetData memory expectedUserData
  ) internal {
    if (_debugFlag) console.log('checkUserAssetData', 'begin');
    assertEq(afterUserData.walletBalance, expectedUserData.walletBalance, 'UAD:walletBalance');

    assertEq(afterUserData.totalCrossSupply, expectedUserData.totalCrossSupply, 'UAD:totalCrossSupply');
    assertEq(afterUserData.totalIsolateSupply, expectedUserData.totalIsolateSupply, 'UAD:walletBalance');

    for (uint256 i = 0; i < afterUserData.groupsData.length; i++) {
      if (_debugFlag) console.log('checkUserAssetData', 'group', i);
      TestUserGroupData memory afterGroupData = afterUserData.groupsData[i];
      TestUserGroupData memory expectedGroupData = expectedUserData.groupsData[i];

      assertEq(afterGroupData.totalCrossBorrow, expectedGroupData.totalCrossBorrow, 'UAD:totalCrossBorrow');
      assertEq(afterGroupData.totalIsolateBorrow, expectedGroupData.totalIsolateBorrow, 'UAD:totalIsolateBorrow');
    }
    if (_debugFlag) console.log('checkUserAssetData', 'end');
  }

  function checkAccoutData(
    TestAction /*action*/,
    TestUserAccountData memory afterAccoutData,
    TestUserAccountData memory expectedAccoutData
  ) internal {
    if (_debugFlag) console.log('checkAccoutData', 'begin');
    if (_debugFlag) console.log('checkAccoutData', 'end');
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
    if (_debugFlag) console.log('calcExpectedAssetDataAfterDepositERC20', 'begin');
    expectedAssetData = copyAssetData(dataBefore.assetData);

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    // supply
    expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply + amountDeposited;
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply + amountDeposited;

    // borrow

    expectedAssetData.totalLiquidity =
      expectedAssetData.totalCrossBorrow +
      expectedAssetData.totalIsolateBorrow +
      expectedAssetData.availableSupply;
    expectedAssetData.utilizationRate = calcExpectedUtilizationRate(
      expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow,
      expectedAssetData.totalLiquidity
    );

    // rate
    calcExpectedInterestRates(expectedAssetData);
    if (_debugFlag) console.log('calcExpectedAssetDataAfterDepositERC20', 'end');
  }

  function calcExpectedUserDataAfterDepositERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountDeposited,
    uint256 /*txTimestamp*/
  ) internal view returns (TestUserAssetData memory expectedUserData) {
    if (_debugFlag) console.log('calcExpectedUserDataAfterDepositERC20', 'begin');
    expectedUserData = copyUserAssetData(dataBefore.userAssetData);

    // supply
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance - amountDeposited;

    expectedUserData.totalCrossSupply = dataBefore.userAssetData.totalCrossSupply + amountDeposited;

    // borrow

    if (_debugFlag) console.log('calcExpectedUserDataAfterDepositERC20', 'end');
  }

  /* WithdrawERC20 */

  function calcExpectedAssetDataAfterWithdrawERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint256 txTimestamp
  ) internal view returns (TestAssetData memory expectedAssetData) {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterWithdrawERC20', 'begin');
    expectedAssetData = copyAssetData(dataBefore.assetData);

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    // supply
    expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply - amountWithdrawn;
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - amountWithdrawn;

    // borrow

    expectedAssetData.totalLiquidity =
      expectedAssetData.totalCrossBorrow +
      expectedAssetData.totalIsolateBorrow +
      expectedAssetData.availableSupply;
    expectedAssetData.utilizationRate = calcExpectedUtilizationRate(
      expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow,
      expectedAssetData.totalLiquidity
    );

    // rate
    calcExpectedInterestRates(expectedAssetData);
    if (_debugFlag) console.log('calcExpectedAssetDataAfterWithdrawERC20', 'end');
  }

  function calcExpectedUserDataAfterWithdrawERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint256 /*txTimestamp*/
  ) internal view returns (TestUserAssetData memory expectedUserData) {
    if (_debugFlag) console.log('calcExpectedUserDataAfterWithdrawERC20', 'begin');
    expectedUserData = copyUserAssetData(dataBefore.userAssetData);

    // supply
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance + amountWithdrawn;

    expectedUserData.totalCrossSupply = dataBefore.userAssetData.totalCrossSupply - amountWithdrawn;

    // borrow

    if (_debugFlag) console.log('calcExpectedUserDataAfterWithdrawERC20', 'end');
  }

  /* DepositERC721 */

  function calcExpectedAssetDataAfterDepositERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountDeposited,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view returns (TestAssetData memory expectedAssetData) {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterDepositERC721', 'begin');
    expectedAssetData = copyAssetData(dataBefore.assetData);

    // index, no need for erc721

    // supply
    if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply + amountDeposited;
    } else if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedAssetData.totalIsolateSupply = dataBefore.assetData.totalIsolateSupply + amountDeposited;
    }
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply + amountDeposited;

    // borrow

    expectedAssetData.totalLiquidity =
      expectedAssetData.totalCrossBorrow +
      expectedAssetData.totalIsolateBorrow +
      expectedAssetData.availableSupply;

    // rate, no need for erc721

    if (_debugFlag) console.log('calcExpectedAssetDataAfterDepositERC721', 'end');
  }

  function calcExpectedUserDataAfterDepositERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountDeposited,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view returns (TestUserAssetData memory expectedUserData) {
    if (_debugFlag) console.log('calcExpectedUserDataAfterDepositERC721', 'begin');
    expectedUserData = copyUserAssetData(dataBefore.userAssetData);

    // supply
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance - amountDeposited;

    if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedUserData.totalCrossSupply = dataBefore.userAssetData.totalCrossSupply + amountDeposited;
    } else if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedUserData.totalIsolateSupply = dataBefore.userAssetData.totalIsolateSupply + amountDeposited;
    }

    // borrow

    if (_debugFlag) console.log('calcExpectedUserDataAfterDepositERC721', 'end');
  }

  /* WithdrawERC721 */

  function calcExpectedAssetDataAfterWithdrawERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view returns (TestAssetData memory expectedAssetData) {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterWithdrawERC721', 'begin');
    expectedAssetData = copyAssetData(dataBefore.assetData);

    // index, no need for erc721

    // supply
    if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply - amountWithdrawn;
    } else if (supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      expectedAssetData.totalIsolateSupply = dataBefore.assetData.totalIsolateSupply - amountWithdrawn;
    }

    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - amountWithdrawn;
    expectedAssetData.totalLiquidity = expectedAssetData.totalLiquidity - amountWithdrawn;

    // borrow

    // rate, no need for erc721

    if (_debugFlag) console.log('calcExpectedAssetDataAfterWithdrawERC721', 'end');
  }

  function calcExpectedUserDataAfterWithdrawERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint256 amountWithdrawn,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view returns (TestUserAssetData memory expectedUserData) {
    if (_debugFlag) console.log('calcExpectedUserDataAfterWithdrawERC721', 'begin');
    expectedUserData = copyUserAssetData(dataBefore.userAssetData);

    // supply
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance + amountWithdrawn;

    if (supplyMode == Constants.SUPPLY_MODE_CROSS) {
      expectedUserData.totalCrossSupply = dataBefore.userAssetData.totalCrossSupply - amountWithdrawn;
    } else if (supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      expectedUserData.totalIsolateSupply = dataBefore.userAssetData.totalIsolateSupply - amountWithdrawn;
    }

    // borrow

    if (_debugFlag) console.log('calcExpectedUserDataAfterWithdrawERC721', 'end');
  }

  /* CrossBorrowERC20 */

  function calcExpectedAssetDataAfterCrossBorrowERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint8[] memory groups,
    uint256[] memory amounts,
    uint256 txTimestamp
  ) internal view returns (TestAssetData memory expectedAssetData) {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterCrossBorrowERC20', 'begin');
    expectedAssetData = copyAssetData(dataBefore.assetData);

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    uint256 totalAmountBorrowed;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmountBorrowed += amounts[i];
    }

    // supply
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - totalAmountBorrowed;

    expectedAssetData.supplyIndex = calcExpectedSupplyIndex(
      dataBefore.assetData.utilizationRate,
      dataBefore.assetData.supplyRate,
      dataBefore.assetData.supplyIndex,
      dataBefore.assetData.lastUpdateTimestamp,
      txTimestamp
    );

    // borrow
    expectedAssetData.totalCrossBorrow = dataBefore.assetData.totalCrossBorrow + totalAmountBorrowed;

    expectedAssetData.totalLiquidity =
      expectedAssetData.totalCrossBorrow +
      expectedAssetData.totalIsolateBorrow +
      expectedAssetData.availableSupply;
    expectedAssetData.utilizationRate = calcExpectedUtilizationRate(
      expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow,
      expectedAssetData.totalLiquidity
    );

    for (uint256 i = 0; i < groups.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[groups[i]];
      expectedGroupData.totalCrossBorrow += amounts[i];
    }

    // rate
    calcExpectedInterestRates(expectedAssetData);

    if (_debugFlag) console.log('calcExpectedAssetDataAfterCrossBorrowERC20', 'end');
  }

  function calcExpectedUserDataAfterCrossBorrowERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    uint8[] memory groups,
    uint256[] memory amounts,
    uint256 /*txTimestamp*/
  ) internal view returns (TestUserAssetData memory expectedUserData) {
    if (_debugFlag) console.log('calcExpectedUserDataAfterCrossBorrowERC20', 'begin');
    expectedUserData = copyUserAssetData(dataBefore.userAssetData);

    uint256 totalAmountBorrowed;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmountBorrowed += amounts[i];
    }

    // supply
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance + totalAmountBorrowed;

    // borrow
    expectedUserData.totalCrossBorrow = dataBefore.userAssetData.totalCrossBorrow + totalAmountBorrowed;

    for (uint256 i = 0; i < groups.length; i++) {
      TestUserGroupData memory expectedGroupData = expectedUserData.groupsData[groups[i]];
      expectedGroupData.totalCrossBorrow += amounts[i];
    }
    if (_debugFlag) console.log('calcExpectedUserDataAfterCrossBorrowERC20', 'end');
  }

  /* CrossRepayERC20 */

  function calcExpectedAssetDataAfterCrossRepayERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint8[] memory groups,
    uint256[] memory amounts,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterCrossRepayERC20', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    uint256 totalAmountRepaid;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmountRepaid += amounts[i];
    }

    // supply
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply + totalAmountRepaid;

    expectedAssetData.supplyIndex = calcExpectedSupplyIndex(
      dataBefore.assetData.utilizationRate,
      dataBefore.assetData.supplyRate,
      dataBefore.assetData.supplyIndex,
      dataBefore.assetData.lastUpdateTimestamp,
      txTimestamp
    );

    // borrow
    expectedAssetData.totalCrossBorrow = dataBefore.assetData.totalCrossBorrow - totalAmountRepaid;

    expectedAssetData.totalLiquidity =
      expectedAssetData.totalCrossBorrow +
      expectedAssetData.totalIsolateBorrow +
      expectedAssetData.availableSupply;
    expectedAssetData.utilizationRate = calcExpectedUtilizationRate(
      expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow,
      expectedAssetData.totalLiquidity
    );

    for (uint256 i = 0; i < groups.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[groups[i]];
      expectedGroupData.totalCrossBorrow -= amounts[i];
    }

    // rate
    calcExpectedInterestRates(expectedAssetData);

    if (_debugFlag) console.log('calcExpectedAssetDataAfterCrossRepayERC20', 'end');
  }

  function calcExpectedUserDataAfterCrossRepayERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint8[] memory groups,
    uint256[] memory amounts,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedUserDataAfterRepayBorrowERC20', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserAssetData;

    uint256 totalAmountRepaid;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmountRepaid += amounts[i];
    }

    // supply
    expectedUserAssetData.walletBalance = dataBefore.userAssetData.walletBalance - totalAmountRepaid;

    // borrow
    for (uint256 i = 0; i < groups.length; i++) {
      TestGroupData memory expectedAssetGroupData = dataExpected.assetData.groupsData[groups[i]];
      TestUserGroupData memory expectedUserGroupData = expectedUserAssetData.groupsData[groups[i]];
      TestUserGroupData memory beforeUserGroupData = dataBefore.userAssetData.groupsData[groups[i]];

      expectedUserGroupData.totalCrossBorrow = calcExpectedTotalBorrow(
        beforeUserGroupData.totalScaledCrossBorrow,
        expectedAssetGroupData.borrowIndex
      );
      expectedUserGroupData.totalCrossBorrow -= amounts[i];
    }
    expectedUserAssetData.totalCrossBorrow = dataBefore.userAssetData.totalCrossBorrow - totalAmountRepaid;

    if (_debugFlag) console.log('calcExpectedUserDataAfterRepayBorrowERC20', 'end');
  }

  /****************************************************************************/
  /* Helpers for Calculations */
  /****************************************************************************/
  function calcExpectedInterestIndexs(
    TestAssetData memory beforeAssetData,
    TestAssetData memory expectedAssetData,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedInterestIndexs', 'begin');

    expectedAssetData.supplyIndex = calcExpectedSupplyIndex(
      beforeAssetData.utilizationRate,
      beforeAssetData.supplyRate,
      beforeAssetData.supplyIndex,
      beforeAssetData.lastUpdateTimestamp,
      txTimestamp
    );

    if (_debugFlag)
      console.log('calcExpectedInterestIndexs-supplyIndex', beforeAssetData.supplyIndex, expectedAssetData.supplyIndex);

    for (uint256 i = 0; i < expectedAssetData.groupsData.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];
      TestGroupData memory beforeGroupData = beforeAssetData.groupsData[i];

      expectedGroupData.borrowIndex = calcExpectedBorrowIndex(
        beforeGroupData.totalCrossBorrow + beforeGroupData.totalIsolateBorrow,
        beforeGroupData.borrowRate,
        beforeGroupData.borrowIndex,
        beforeAssetData.lastUpdateTimestamp,
        txTimestamp
      );

      if (_debugFlag)
        console.log(
          'calcExpectedInterestIndexs-borrowIndex',
          i,
          beforeGroupData.borrowIndex,
          expectedGroupData.borrowIndex
        );
    }

    if (_debugFlag) console.log('calcExpectedInterestIndexs', 'end');
  }

  function calcExpectedInterestRates(TestAssetData memory expectedAssetData) internal view {
    if (_debugFlag) console.log('calcExpectedInterestRates', 'begin');
    uint256 totalBorrowRate;
    uint256 totalBorrowInAsset = expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow;
    for (uint256 i = 0; i < expectedAssetData.groupsData.length; i++) {
      TestGroupData memory groupData = expectedAssetData.groupsData[i];
      if ((groupData.totalCrossBorrow + groupData.totalIsolateBorrow) > 0) {
        require(groupData.rateModel != address(0), 'invalid rate model address');
      }

      if (groupData.rateModel == address(0)) {
        groupData.borrowRate = 0;
        continue;
      }

      groupData.borrowRate = IInterestRateModel(groupData.rateModel).calculateGroupBorrowRate(
        expectedAssetData.utilizationRate
      );
      if (_debugFlag) console.log('calcExpectedInterestRates-borrowRate', i, groupData.borrowRate);

      if (totalBorrowInAsset > 0) {
        totalBorrowRate += (groupData.borrowRate.rayMul(groupData.totalCrossBorrow + groupData.totalIsolateBorrow))
          .rayDiv(totalBorrowInAsset);
      }
    }

    expectedAssetData.supplyRate = totalBorrowRate.rayMul(expectedAssetData.utilizationRate);
    expectedAssetData.supplyRate = expectedAssetData.supplyRate.percentMul(
      PercentageMath.PERCENTAGE_FACTOR - expectedAssetData.config.feeFactor
    );

    if (_debugFlag) console.log('calcExpectedInterestRates-supplyRate', expectedAssetData.supplyRate);

    if (_debugFlag) console.log('calcExpectedInterestRates', 'end');
  }

  function calcExpectedUtilizationRate(uint256 totalBorrow, uint256 totalSupply) internal pure returns (uint256) {
    if (totalBorrow == 0) return 0;
    return totalBorrow.rayDiv(totalSupply);
  }

  function calcExpectedTotalSupply(uint256 scaledSupply, uint256 expectedIndex) internal pure returns (uint256) {
    return scaledSupply.rayMul(expectedIndex);
  }

  function calcExpectedTotalBorrow(uint256 scaledBorrow, uint256 expectedIndex) internal pure returns (uint256) {
    return scaledBorrow.rayMul(expectedIndex);
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
