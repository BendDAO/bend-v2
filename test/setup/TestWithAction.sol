// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {KVSortUtils} from 'src/libraries/helpers/KVSortUtils.sol';

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
      TestContractData memory dataExpected;
      calcExpectedAssetDataAfterDepositERC20(dataBefore, dataAfter, dataExpected, amount, txTimestamp);
      calcExpectedUserDataAfterDepositERC20(dataBefore, dataAfter, dataExpected, amount, txTimestamp);

      // check the results
      checkAssetData(TestAction.DepositERC20, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.DepositERC20, dataAfter.userAssetData, dataExpected.userAssetData);
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
      TestContractData memory dataExpected;
      calcExpectedAssetDataAfterWithdrawERC20(dataBefore, dataAfter, dataExpected, amount, txTimestamp);
      calcExpectedUserDataAfterWithdrawERC20(dataBefore, dataAfter, dataExpected, amount, txTimestamp);

      // check the results
      checkAssetData(TestAction.WithdrawERC20, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.WithdrawERC20, dataAfter.userAssetData, dataExpected.userAssetData);
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
      TestContractData memory dataExpected;
      calcExpectedAssetDataAfterDepositERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );
      calcExpectedUserDataAfterDepositERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.DepositERC721, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.DepositERC721, dataAfter.userAssetData, dataExpected.userAssetData);
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
      TestContractData memory dataBefore = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC721);

      // send tx
      if (_debugFlag) console.log('actionWithdrawERC721', 'sendtx');
      tsHEVM.prank(sender);
      tsPoolManager.withdrawERC721(poolId, asset, tokenIds, supplyMode);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      TestContractData memory dataAfter = getContractData(sender, poolId, asset, Constants.ASSET_TYPE_ERC721);

      // calc expected data
      TestContractData memory dataExpected;
      calcExpectedAssetDataAfterWithdrawERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );
      calcExpectedUserDataAfterWithdrawERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        tokenIds.length,
        supplyMode,
        txTimestamp
      );

      // check the results
      checkAssetData(TestAction.WithdrawERC721, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.WithdrawERC721, dataAfter.userAssetData, dataExpected.userAssetData);
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
      TestContractData memory dataExpected;
      calcExpectedAssetDataAfterCrossBorrowERC20(dataBefore, dataAfter, dataExpected, groups, amounts, txTimestamp);
      calcExpectedUserDataAfterCrossBorrowERC20(dataBefore, dataAfter, dataExpected, groups, amounts, txTimestamp);

      // check the results
      checkAssetData(TestAction.CrossBorrowERC20, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.CrossBorrowERC20, dataAfter.userAssetData, dataExpected.userAssetData);
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

  function actionCrossLiquidateERC20(
    address sender,
    uint32 poolId,
    address user,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    bool supplyAsCollateral,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('<<<<actionCrossLiquidateERC20', 'begin');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.crossLiquidateERC20(poolId, user, collateralAsset, debtAsset, debtToCover, supplyAsCollateral);
    } else {
      // fetch contract data
      // liquidator & collateral
      TestContractData memory dataBefore = getContractData(sender, poolId, collateralAsset, Constants.ASSET_TYPE_ERC20);

      // liquidator & debt
      dataBefore.assetData2 = getAssetData(poolId, debtAsset, Constants.ASSET_TYPE_ERC20);
      dataBefore.userAssetData2 = getUserAssetData(sender, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // borrower & collateral
      dataBefore.userAssetData3 = getUserAssetData(user, poolId, collateralAsset, Constants.ASSET_TYPE_ERC20);

      // borrower & debt
      dataBefore.userAssetData4 = getUserAssetData(user, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // send tx
      if (_debugFlag) console.log('actionCrossLiquidateERC20', 'sendtx');
      tsHEVM.prank(sender);
      tsPoolManager.crossLiquidateERC20(poolId, user, collateralAsset, debtAsset, debtToCover, supplyAsCollateral);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      // liquidator & collateral
      TestContractData memory dataAfter = getContractData(sender, poolId, collateralAsset, Constants.ASSET_TYPE_ERC20);

      console.log('actionCrossLiquidateERC20-111', dataAfter.assetData.totalCrossSupply);

      // liquidator & debt
      dataAfter.assetData2 = getAssetData(poolId, debtAsset, Constants.ASSET_TYPE_ERC20);
      dataAfter.userAssetData2 = getUserAssetData(sender, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // borrower & collateral
      dataAfter.userAssetData3 = getUserAssetData(user, poolId, collateralAsset, Constants.ASSET_TYPE_ERC20);

      // borrower & debt
      dataAfter.userAssetData4 = getUserAssetData(user, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // calc expected data
      TestContractData memory dataExpected;

      uint256 colToLiq = calcExpectedCollateralFromDebtToCover(
        dataBefore.assetData,
        dataBefore.assetData2,
        dataBefore.userAssetData3,
        debtToCover
      );

      debtToCover = calcExpectedDebtToCoverFromERC20(dataBefore.assetData, dataBefore.assetData2, colToLiq);

      calcExpectedCollateralAssetDataAfterCrossLiquidateERC20(
        dataBefore,
        dataAfter,
        dataExpected,
        colToLiq,
        txTimestamp
      );
      calcExpectedDebtAssetDataAfterCrossLiquidateERC20(dataBefore, dataAfter, dataExpected, debtToCover, txTimestamp);

      calcExpectedLiquidatorColUserDataAfterCrossLiquidateERC20(
        dataBefore,
        dataAfter,
        dataExpected,
        colToLiq,
        txTimestamp
      );
      calcExpectedLiquidatorDebtUserDataAfterCrossLiquidateERC20(
        dataBefore,
        dataAfter,
        dataExpected,
        debtToCover,
        txTimestamp
      );

      calcExpectedBorrowerColUserDataAfterCrossLiquidateERC20(
        dataBefore,
        dataAfter,
        dataExpected,
        colToLiq,
        txTimestamp
      );
      calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC20(
        dataBefore,
        dataAfter,
        dataExpected,
        debtToCover,
        txTimestamp
      );

      // check the results
      // liquidator & collateral
      if (_debugFlag) console.log('actionCrossLiquidateERC20', 'check: liquidator & collateral');
      checkAssetData(TestAction.CrossLiquidateERC20, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.CrossLiquidateERC20, dataAfter.userAssetData, dataExpected.userAssetData);

      // liquidator & debt
      if (_debugFlag) console.log('actionCrossLiquidateERC20', 'check: liquidator & debt');
      checkAssetData(TestAction.CrossLiquidateERC20, dataAfter.assetData2, dataExpected.assetData2);
      checkUserAssetData(TestAction.CrossLiquidateERC20, dataAfter.userAssetData2, dataExpected.userAssetData2);

      // borrower & collateral
      if (_debugFlag) console.log('actionCrossLiquidateERC20', 'check: borrower & collateral');
      checkUserAssetData(TestAction.CrossLiquidateERC20, dataAfter.userAssetData3, dataExpected.userAssetData3);

      // borrower & debt
      if (_debugFlag) console.log('actionCrossLiquidateERC20', 'check: borrower & debt');
      checkUserAssetData(TestAction.CrossLiquidateERC20, dataAfter.userAssetData4, dataExpected.userAssetData4);
    }
    if (_debugFlag) console.log('>>>>actionCrossLiquidateERC20', 'end');
  }

  function actionCrossLiquidateERC721(
    address sender,
    uint32 poolId,
    address user,
    address collateralAsset,
    uint256[] memory tokenIds,
    address debtAsset,
    bool supplyAsCollateral,
    bytes memory revertMessage
  ) internal {
    if (_debugFlag) console.log('<<<<actionCrossLiquidateERC721', 'begin');
    if (revertMessage.length > 0) {
      vm.expectRevert(revertMessage);
      tsHEVM.prank(sender);
      tsPoolManager.crossLiquidateERC721(poolId, user, collateralAsset, tokenIds, debtAsset, supplyAsCollateral);
    } else {
      // fetch contract data
      // liquidator & collateral
      TestContractData memory dataBefore = getContractData(
        sender,
        poolId,
        collateralAsset,
        Constants.ASSET_TYPE_ERC721
      );

      // liquidator & debt
      dataBefore.assetData2 = getAssetData(poolId, debtAsset, Constants.ASSET_TYPE_ERC20);
      dataBefore.userAssetData2 = getUserAssetData(sender, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // borrower & collateral
      dataBefore.userAssetData3 = getUserAssetData(user, poolId, collateralAsset, Constants.ASSET_TYPE_ERC721);

      // borrower & debt
      dataBefore.userAssetData4 = getUserAssetData(user, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // send tx
      if (_debugFlag) console.log('actionCrossLiquidateERC721', 'sendtx');
      tsHEVM.prank(sender);
      tsPoolManager.crossLiquidateERC721(poolId, user, collateralAsset, tokenIds, debtAsset, supplyAsCollateral);
      uint256 txTimestamp = block.timestamp;

      // fetch contract data
      // liquidator & collateral
      TestContractData memory dataAfter = getContractData(sender, poolId, collateralAsset, Constants.ASSET_TYPE_ERC721);

      // liquidator & debt
      dataAfter.assetData2 = getAssetData(poolId, debtAsset, Constants.ASSET_TYPE_ERC20);
      dataAfter.userAssetData2 = getUserAssetData(sender, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // borrower & collateral
      dataAfter.userAssetData3 = getUserAssetData(user, poolId, collateralAsset, Constants.ASSET_TYPE_ERC721);

      // borrower & debt
      dataAfter.userAssetData4 = getUserAssetData(user, poolId, debtAsset, Constants.ASSET_TYPE_ERC20);

      // calc expected data
      TestContractData memory dataExpected;

      uint256 colToLiq = tokenIds.length;
      uint256 debtToCover = calcExpectedDebtToCoverFromERC721(dataBefore.assetData, dataBefore.assetData2, colToLiq);

      calcExpectedCollateralAssetDataAfterCrossLiquidateERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        colToLiq,
        txTimestamp
      );
      calcExpectedDebtAssetDataAfterCrossLiquidateERC721(dataBefore, dataAfter, dataExpected, debtToCover, txTimestamp);

      calcExpectedLiquidatorColUserDataAfterCrossLiquidateERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        colToLiq,
        txTimestamp
      );
      calcExpectedLiquidatorDebtUserDataAfterCrossLiquidateERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        debtToCover,
        txTimestamp
      );

      calcExpectedBorrowerColUserDataAfterCrossLiquidateERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        colToLiq,
        txTimestamp
      );
      calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC721(
        dataBefore,
        dataAfter,
        dataExpected,
        debtToCover,
        txTimestamp
      );

      // check the results
      // liquidator & collateral
      if (_debugFlag) console.log('actionCrossLiquidateERC721', 'check: liquidator & collateral');
      checkAssetData(TestAction.CrossLiquidateERC721, dataAfter.assetData, dataExpected.assetData);
      checkUserAssetData(TestAction.CrossLiquidateERC721, dataAfter.userAssetData, dataExpected.userAssetData);

      // liquidator & debt
      if (_debugFlag) console.log('actionCrossLiquidateERC721', 'check: liquidator & debt');
      checkAssetData(TestAction.CrossLiquidateERC721, dataAfter.assetData2, dataExpected.assetData2);
      checkUserAssetData(TestAction.CrossLiquidateERC721, dataAfter.userAssetData2, dataExpected.userAssetData2);

      // borrower & collateral
      if (_debugFlag) console.log('actionCrossLiquidateERC721', 'check: borrower & collateral');
      checkUserAssetData(TestAction.CrossLiquidateERC721, dataAfter.userAssetData3, dataExpected.userAssetData3);

      // borrower & debt
      if (_debugFlag) console.log('actionCrossLiquidateERC721', 'check: borrower & debt');
      checkUserAssetData(TestAction.CrossLiquidateERC721, dataAfter.userAssetData4, dataExpected.userAssetData4);
    }
    if (_debugFlag) console.log('>>>>actionCrossLiquidateERC721', 'end');
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
    TestContractData memory dataExpected,
    uint256 amountDeposited,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterDepositERC20', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    // balances
    calcExpectedAssetBalances(dataBefore.assetData, expectedAssetData);

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
    TestContractData memory dataExpected,
    uint256 amountDeposited,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedUserDataAfterDepositERC20', 'begin');
    TestUserAssetData memory expectedUserData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance - amountDeposited;

    // supply
    expectedUserData.totalCrossSupply = dataBefore.userAssetData.totalCrossSupply + amountDeposited;

    // borrow

    if (_debugFlag) console.log('calcExpectedUserDataAfterDepositERC20', 'end');
  }

  /* WithdrawERC20 */

  function calcExpectedAssetDataAfterWithdrawERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 amountWithdrawn,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterWithdrawERC20', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    // balances
    calcExpectedAssetBalances(dataExpected.assetData, dataExpected.assetData);

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
    TestContractData memory dataExpected,
    uint256 amountWithdrawn,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedUserDataAfterWithdrawERC20', 'begin');
    TestUserAssetData memory expectedUserData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance + amountWithdrawn;

    // supply

    expectedUserData.totalCrossSupply = dataBefore.userAssetData.totalCrossSupply - amountWithdrawn;

    // borrow

    if (_debugFlag) console.log('calcExpectedUserDataAfterWithdrawERC20', 'end');
  }

  /* DepositERC721 */

  function calcExpectedAssetDataAfterDepositERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 amountDeposited,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterDepositERC721', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

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
    TestContractData memory dataExpected,
    uint256 amountDeposited,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedUserDataAfterDepositERC721', 'begin');
    TestUserAssetData memory expectedUserData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance - amountDeposited;

    // supply
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
    TestContractData memory dataExpected,
    uint256 amountWithdrawn,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterWithdrawERC721', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

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
    TestContractData memory dataExpected,
    uint256 amountWithdrawn,
    uint8 supplyMode,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedUserDataAfterWithdrawERC721', 'begin');
    TestUserAssetData memory expectedUserData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet

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
    TestContractData memory dataExpected,
    uint8[] memory groups,
    uint256[] memory amounts,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedAssetDataAfterCrossBorrowERC20', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

    uint256 totalAmountBorrowed;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmountBorrowed += amounts[i];
    }

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    // balances
    calcExpectedAssetBalances(dataExpected.assetData, dataExpected.assetData);

    // supply
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - totalAmountBorrowed;

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
    TestContractData memory dataExpected,
    uint8[] memory groups,
    uint256[] memory amounts,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedUserDataAfterCrossBorrowERC20', 'begin');
    TestUserAssetData memory expectedUserData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserData;

    uint256 totalAmountBorrowed;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmountBorrowed += amounts[i];
    }

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet
    expectedUserData.walletBalance = dataBefore.userAssetData.walletBalance + totalAmountBorrowed;

    // supply

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

    uint256 totalAmountRepaid;
    for (uint256 i = 0; i < amounts.length; i++) {
      totalAmountRepaid += amounts[i];
    }

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    // balances
    calcExpectedAssetBalances(dataExpected.assetData, dataExpected.assetData);

    // supply
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply + totalAmountRepaid;

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

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet

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

  // CrossLiquidateERC20

  function calcExpectedCollateralFromDebtToCover(
    TestAssetData memory collateralAssetData,
    TestAssetData memory debtAssetData,
    TestUserAssetData memory borrowerAssetData,
    uint256 debtToCover
  ) internal view returns (uint256 colAmount) {
    uint256 colPrice = tsPriceOracle.getAssetPrice(collateralAssetData.asset);
    uint256 debtPrice = tsPriceOracle.getAssetPrice(debtAssetData.asset);

    colAmount =
      (debtToCover * debtPrice * (10 ** collateralAssetData.config.decimals)) /
      ((10 ** debtAssetData.config.decimals) * colPrice);
    colAmount = colAmount.percentMul(PercentageMath.PERCENTAGE_FACTOR + collateralAssetData.config.liquidationBonus);
    if (colAmount > borrowerAssetData.totalCrossSupply) {
      colAmount = borrowerAssetData.totalCrossSupply;
    }

    if (_debugFlag) console.log('calcExpectedCollateralERC20FromDebtToCover', colAmount);
  }

  function calcExpectedDebtToCoverFromERC20(
    TestAssetData memory collateralAssetData,
    TestAssetData memory debtAssetData,
    uint256 colAmount
  ) internal view returns (uint256 debtToCover) {
    uint256 colPrice = tsPriceOracle.getAssetPrice(collateralAssetData.asset);
    uint256 debtPrice = tsPriceOracle.getAssetPrice(debtAssetData.asset);

    debtToCover =
      (colAmount * colPrice * (10 ** debtAssetData.config.decimals)) /
      ((10 ** collateralAssetData.config.decimals) * debtPrice);
    debtToCover = debtToCover.percentDiv(
      PercentageMath.PERCENTAGE_FACTOR + collateralAssetData.config.liquidationBonus
    );

    if (_debugFlag) console.log('calcExpectedDebtToCoverFromERC20', debtToCover);
  }

  function calcExpectedCollateralAssetDataAfterCrossLiquidateERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 colToLiq,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedCollateralAssetDataAfterCrossLiquidateERC20', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

    // index
    calcExpectedInterestIndexs(dataBefore.assetData, expectedAssetData, txTimestamp);

    // balances
    calcExpectedAssetBalances(dataExpected.assetData, dataExpected.assetData);

    // supply
    expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply - colToLiq;
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - colToLiq;

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

    if (_debugFlag) console.log('calcExpectedCollateralAssetDataAfterCrossLiquidateERC20', 'end');
  }

  function calcExpectedDebtAssetDataAfterCrossLiquidateERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 debtToCover,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedDebtAssetDataAfterCrossLiquidateERC20', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData2);
    dataExpected.assetData2 = expectedAssetData;

    // index
    calcExpectedInterestIndexs(dataBefore.assetData2, expectedAssetData, txTimestamp);

    // balances
    calcExpectedAssetBalances(dataExpected.assetData2, dataExpected.assetData2);

    // supply
    expectedAssetData.availableSupply = dataBefore.assetData2.availableSupply + debtToCover;

    // borrow
    expectedAssetData.totalCrossBorrow = dataBefore.assetData2.totalCrossBorrow - debtToCover;

    expectedAssetData.totalLiquidity =
      expectedAssetData.totalCrossBorrow +
      expectedAssetData.totalIsolateBorrow +
      expectedAssetData.availableSupply;
    expectedAssetData.utilizationRate = calcExpectedUtilizationRate(
      expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow,
      expectedAssetData.totalLiquidity
    );

    uint8[] memory sortedGroupIds = sortGroupIdByRates(dataBefore.assetData2);
    uint256 remainDebt = debtToCover;
    for (uint256 i = 0; i < sortedGroupIds.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[sortedGroupIds[i]];
      if (expectedGroupData.totalCrossBorrow > remainDebt) {
        expectedGroupData.totalCrossBorrow -= remainDebt;
        remainDebt = 0;
      } else {
        remainDebt -= expectedGroupData.totalCrossBorrow;
        expectedGroupData.totalCrossBorrow = 0;
      }

      if (remainDebt == 0) {
        break;
      }
    }

    // rate
    calcExpectedInterestRates(expectedAssetData);

    if (_debugFlag) console.log('calcExpectedDebtAssetDataAfterCrossLiquidateERC20', 'end');
  }

  function calcExpectedLiquidatorColUserDataAfterCrossLiquidateERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 colToLiq,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedCollateralUserDataAfterCrossLiquidateERC20', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet
    expectedUserAssetData.walletBalance = dataBefore.userAssetData.walletBalance + colToLiq;

    // supply

    // borrow

    if (_debugFlag) console.log('calcExpectedCollateralUserDataAfterCrossLiquidateERC20', 'end');
  }

  function calcExpectedLiquidatorDebtUserDataAfterCrossLiquidateERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 debtToCover,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedDebtUserDataAfterCrossLiquidateERC20', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData2);
    dataExpected.userAssetData2 = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet
    expectedUserAssetData.walletBalance = dataBefore.userAssetData2.walletBalance - debtToCover;

    // supply

    // borrow

    if (_debugFlag) console.log('calcExpectedDebtUserDataAfterCrossLiquidateERC20', 'end');
  }

  function calcExpectedBorrowerColUserDataAfterCrossLiquidateERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 colToLiq,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedBorrowerColUserDataAfterCrossLiquidateERC20', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData3);
    dataExpected.userAssetData3 = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet

    // supply
    expectedUserAssetData.totalCrossSupply = dataBefore.userAssetData3.totalCrossSupply - colToLiq;

    // borrow

    if (_debugFlag) console.log('calcExpectedBorrowerColUserDataAfterCrossLiquidateERC20', 'end');
  }

  function calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC20(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 debtToCover,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC20', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData4);
    dataExpected.userAssetData4 = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet

    // supply

    // borrow
    expectedUserAssetData.totalCrossBorrow = dataBefore.userAssetData4.totalCrossBorrow - debtToCover;

    uint8[] memory sortedGroupIds = sortGroupIdByRates(dataBefore.assetData2);
    uint256 remainDebt = debtToCover;
    for (uint256 i = 0; i < sortedGroupIds.length; i++) {
      TestUserGroupData memory expectedGroupData = expectedUserAssetData.groupsData[sortedGroupIds[i]];
      if (expectedGroupData.totalCrossBorrow == 0) {
        continue;
      }

      if (expectedGroupData.totalCrossBorrow > remainDebt) {
        expectedGroupData.totalCrossBorrow -= remainDebt;
        remainDebt = 0;
      } else {
        remainDebt -= expectedGroupData.totalCrossBorrow;
        expectedGroupData.totalCrossBorrow = 0;
      }

      if (remainDebt == 0) {
        break;
      }
    }

    if (_debugFlag) console.log('calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC20', 'end');
  }

  // CrossLiquidateERC721

  function calcExpectedDebtToCoverFromERC721(
    TestAssetData memory collateralAssetData,
    TestAssetData memory debtAssetData,
    uint256 colAmount
  ) internal view returns (uint256 debtToCover) {
    uint256 colPrice = tsPriceOracle.getAssetPrice(collateralAssetData.asset);
    uint256 debtPrice = tsPriceOracle.getAssetPrice(debtAssetData.asset);

    colPrice = colPrice.percentMul(PercentageMath.PERCENTAGE_FACTOR - collateralAssetData.config.liquidationBonus);

    // no decimals for erc721
    debtToCover = (colAmount * colPrice * (10 ** debtAssetData.config.decimals)) / (debtPrice);

    if (_debugFlag) console.log('calcExpectedDebtToCoverFromERC721', debtToCover);
  }

  function calcExpectedCollateralAssetDataAfterCrossLiquidateERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 colToLiq,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedCollateralAssetDataAfterCrossLiquidateERC721', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData);
    dataExpected.assetData = expectedAssetData;

    // index, no need for erc721

    // supply
    expectedAssetData.totalCrossSupply = dataBefore.assetData.totalCrossSupply - colToLiq;
    expectedAssetData.availableSupply = dataBefore.assetData.availableSupply - colToLiq;

    // borrow

    // rate, no need for erc721

    if (_debugFlag) console.log('calcExpectedCollateralAssetDataAfterCrossLiquidateERC721', 'end');
  }

  function calcExpectedDebtAssetDataAfterCrossLiquidateERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 debtToCover,
    uint256 txTimestamp
  ) internal view {
    if (_debugFlag) console.log('calcExpectedDebtAssetDataAfterCrossLiquidateERC721', 'begin');
    TestAssetData memory expectedAssetData = copyAssetData(dataBefore.assetData2);
    dataExpected.assetData2 = expectedAssetData;

    // index
    calcExpectedInterestIndexs(dataBefore.assetData2, expectedAssetData, txTimestamp);

    // balances
    calcExpectedAssetBalances(dataExpected.assetData2, dataExpected.assetData2);

    // supply
    expectedAssetData.availableSupply = dataBefore.assetData2.availableSupply + debtToCover;

    // borrow
    expectedAssetData.totalCrossBorrow = 0;

    uint8[] memory sortedGroupIds = sortGroupIdByRates(dataBefore.assetData2);
    uint256 remainDebt = debtToCover;
    for (uint256 i = 0; i < sortedGroupIds.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[sortedGroupIds[i]];
      if (expectedGroupData.totalScaledCrossBorrow == 0) {
        continue;
      }
      uint256 totalBorrow = expectedGroupData.totalScaledCrossBorrow.rayMul(expectedGroupData.borrowIndex);
      uint256 curRepayAmount;
      if (totalBorrow > remainDebt) {
        curRepayAmount = remainDebt;
        remainDebt = 0;
      } else {
        curRepayAmount = totalBorrow;
        remainDebt -= curRepayAmount;
      }
      expectedGroupData.totalScaledCrossBorrow -= curRepayAmount.rayDiv(expectedGroupData.borrowIndex);
      expectedGroupData.totalCrossBorrow = expectedGroupData.totalScaledCrossBorrow.rayMul(
        expectedGroupData.borrowIndex
      );

      expectedAssetData.totalCrossBorrow += expectedGroupData.totalCrossBorrow;

      if (remainDebt == 0) {
        break;
      }
    }

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

    if (_debugFlag) console.log('calcExpectedDebtAssetDataAfterCrossLiquidateERC721', 'end');
  }

  function calcExpectedLiquidatorColUserDataAfterCrossLiquidateERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 colToLiq,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedLiquidatorColUserDataAfterCrossLiquidateERC721', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData);
    dataExpected.userAssetData = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData, dataExpected.userAssetData);

    // wallet
    expectedUserAssetData.walletBalance = dataBefore.userAssetData.walletBalance + colToLiq;

    // supply

    // borrow

    if (_debugFlag) console.log('calcExpectedLiquidatorColUserDataAfterCrossLiquidateERC721', 'end');
  }

  function calcExpectedLiquidatorDebtUserDataAfterCrossLiquidateERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 debtToCover,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedLiquidatorDebtUserDataAfterCrossLiquidateERC721', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData2);
    dataExpected.userAssetData2 = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData2, dataBefore.userAssetData2, dataExpected.userAssetData2);

    // wallet
    expectedUserAssetData.walletBalance = dataBefore.userAssetData2.walletBalance - debtToCover;

    // supply

    // borrow

    if (_debugFlag) console.log('calcExpectedLiquidatorDebtUserDataAfterCrossLiquidateERC721', 'end');
  }

  function calcExpectedBorrowerColUserDataAfterCrossLiquidateERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 colToLiq,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedBorrowerColUserDataAfterCrossLiquidateERC721', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData3);
    dataExpected.userAssetData3 = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData, dataBefore.userAssetData3, dataExpected.userAssetData3);

    // wallet

    // supply
    expectedUserAssetData.totalCrossSupply = dataBefore.userAssetData3.totalCrossSupply - colToLiq;

    // borrow

    if (_debugFlag) console.log('calcExpectedBorrowerColUserDataAfterCrossLiquidateERC721', 'end');
  }

  function calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC721(
    TestContractData memory dataBefore,
    TestContractData memory /*dataAfter*/,
    TestContractData memory dataExpected,
    uint256 debtToCover,
    uint256 /*txTimestamp*/
  ) internal view {
    if (_debugFlag) console.log('calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC721', 'begin');
    TestUserAssetData memory expectedUserAssetData = copyUserAssetData(dataBefore.userAssetData4);
    dataExpected.userAssetData4 = expectedUserAssetData;

    // balances
    calcExpectedUserAssetBalances(dataExpected.assetData2, dataBefore.userAssetData4, dataExpected.userAssetData4);

    // wallet

    // supply

    // borrow
    expectedUserAssetData.totalCrossBorrow = 0;

    uint8[] memory sortedGroupIds = sortGroupIdByRates(dataBefore.assetData2);
    uint256 remainDebt = debtToCover;
    for (uint256 i = 0; i < sortedGroupIds.length; i++) {
      TestGroupData memory expectedGroupData = dataExpected.assetData2.groupsData[sortedGroupIds[i]];
      TestUserGroupData memory expectedUserGroupData = expectedUserAssetData.groupsData[sortedGroupIds[i]];
      if (expectedUserGroupData.totalScaledCrossBorrow == 0) {
        continue;
      }

      uint256 totalBorrow = expectedUserGroupData.totalScaledCrossBorrow.rayMul(expectedGroupData.borrowIndex);
      uint256 curRepayAmount;
      if (totalBorrow > remainDebt) {
        curRepayAmount = remainDebt;
        remainDebt = 0;
      } else {
        curRepayAmount = totalBorrow;
        remainDebt -= curRepayAmount;
      }
      expectedUserGroupData.totalScaledCrossBorrow -= curRepayAmount.rayDiv(expectedGroupData.borrowIndex);
      expectedUserGroupData.totalCrossBorrow = expectedUserGroupData.totalScaledCrossBorrow.rayMul(
        expectedGroupData.borrowIndex
      );

      expectedUserAssetData.totalCrossBorrow += expectedUserGroupData.totalCrossBorrow;

      if (remainDebt == 0) {
        break;
      }
    }

    // excessive debt supplied as new collateral to borrower
    expectedUserAssetData.totalCrossSupply = dataBefore.userAssetData4.totalCrossSupply + remainDebt;

    if (_debugFlag) console.log('calcExpectedBorrowerDebtUserDataAfterCrossLiquidateERC721', 'end');
  }

  /****************************************************************************/
  /* Helpers for Calculations */
  /****************************************************************************/
  function sortGroupIdByRates(TestAssetData memory assetData) internal pure returns (uint8[] memory) {
    // sort group id from lowest interest rate to highest
    KVSortUtils.KeyValue[] memory groupRateList = new KVSortUtils.KeyValue[](assetData.groupsData.length);
    for (uint256 i = 0; i < assetData.groupsData.length; i++) {
      groupRateList[i].key = assetData.groupsData[i].groupId;
      groupRateList[i].val = assetData.groupsData[i].borrowRate;
    }

    KVSortUtils.sort(groupRateList);

    uint8[] memory groupIdList = new uint8[](groupRateList.length);
    for (uint256 i = 0; i < assetData.groupsData.length; i++) {
      groupIdList[i] = uint8(groupRateList[i].key);
    }
    return groupIdList;
  }

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

  function calcExpectedAssetBalances(
    TestAssetData memory beforeAssetData,
    TestAssetData memory expectedAssetData
  ) internal view {
    if (_debugFlag) console.log('calcExpectedAssetBalances', 'begin');

    expectedAssetData.totalCrossSupply = beforeAssetData.totalScaledCrossSupply.rayMul(expectedAssetData.supplyIndex);
    expectedAssetData.totalIsolateSupply = beforeAssetData.totalScaledIsolateSupply.rayMul(
      expectedAssetData.supplyIndex
    );

    expectedAssetData.totalCrossBorrow = 0;
    expectedAssetData.totalIsolateBorrow = 0;

    for (uint256 i = 0; i < beforeAssetData.groupsData.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];
      TestGroupData memory beforeGroupData = beforeAssetData.groupsData[i];

      expectedGroupData.totalCrossBorrow = beforeGroupData.totalScaledCrossBorrow.rayMul(expectedGroupData.borrowIndex);
      expectedGroupData.totalIsolateBorrow = beforeGroupData.totalScaledIsolateBorrow.rayMul(
        expectedGroupData.borrowIndex
      );

      expectedAssetData.totalCrossBorrow += expectedGroupData.totalCrossBorrow;
      expectedAssetData.totalIsolateBorrow += expectedGroupData.totalIsolateBorrow;
    }

    expectedAssetData.totalLiquidity =
      expectedAssetData.totalCrossBorrow +
      expectedAssetData.totalIsolateBorrow +
      beforeAssetData.availableSupply;
    if (expectedAssetData.totalLiquidity > 0) {
      expectedAssetData.utilizationRate = (expectedAssetData.totalCrossBorrow + expectedAssetData.totalIsolateBorrow)
        .rayDiv(expectedAssetData.totalLiquidity);
    }

    if (_debugFlag) console.log('calcExpectedAssetBalances', 'end');
  }

  function calcExpectedUserAssetBalances(
    TestAssetData memory expectedAssetData,
    TestUserAssetData memory beforeUserAssetData,
    TestUserAssetData memory expectedUserAssetData
  ) internal view {
    if (_debugFlag) console.log('calcExpectedUserAssetBalances', 'begin');

    expectedUserAssetData.totalCrossSupply = beforeUserAssetData.totalScaledCrossSupply.rayMul(
      expectedAssetData.supplyIndex
    );
    expectedUserAssetData.totalIsolateSupply = beforeUserAssetData.totalScaledIsolateSupply.rayMul(
      expectedAssetData.supplyIndex
    );

    expectedUserAssetData.totalCrossBorrow = 0;
    expectedUserAssetData.totalIsolateBorrow = 0;

    for (uint256 i = 0; i < beforeUserAssetData.groupsData.length; i++) {
      TestGroupData memory expectedGroupData = expectedAssetData.groupsData[i];
      TestUserGroupData memory expectedUserGroupData = expectedUserAssetData.groupsData[i];
      TestUserGroupData memory beforeUserGroupData = beforeUserAssetData.groupsData[i];

      expectedUserGroupData.totalCrossBorrow = beforeUserGroupData.totalScaledCrossBorrow.rayMul(
        expectedGroupData.borrowIndex
      );
      expectedUserGroupData.totalIsolateBorrow = beforeUserGroupData.totalScaledIsolateBorrow.rayMul(
        expectedGroupData.borrowIndex
      );

      expectedUserAssetData.totalCrossBorrow += expectedUserGroupData.totalCrossBorrow;
      expectedUserAssetData.totalIsolateBorrow += expectedUserGroupData.totalIsolateBorrow;
    }

    if (_debugFlag) console.log('calcExpectedUserAssetBalances', 'end');
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
