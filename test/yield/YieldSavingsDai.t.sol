// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';

import 'test/setup/TestWithPrepare.sol';
import '@forge-std/Test.sol';

contract TestYieldSavingsDai is TestWithPrepare {
  struct YieldTestVars {
    uint32 poolId;
    uint8 state;
    uint256 debtAmount;
    uint256 yieldAmount;
    uint256 unstakeFine;
    uint256 withdrawAmount;
    uint256 withdrawReqId;
    uint256 totalFineBefore;
    uint256 totalFineAfter;
    uint256 claimedFine;
  }

  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();

    initYieldEthStaking();
  }

  function test_Should_stake() public {
    YieldTestVars memory testVars;

    prepareDAI(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldSavingsDai.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldSavingsDai.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.poolId, tsCommonPoolId, 'poolId not eq');
    assertEq(testVars.state, Constants.YIELD_STATUS_ACTIVE, 'state not eq');
    testEquality(testVars.debtAmount, stakeAmount, 'testVars.debtAmount not eq');
    testEquality(testVars.yieldAmount, stakeAmount, 'testVars.yieldAmount not eq');

    uint256 debtAmount = tsYieldSavingsDai.getNftDebtInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    testEquality(debtAmount, stakeAmount, 'debtAmount not eq');

    (uint256 yieldAmount, ) = tsYieldSavingsDai.getNftYieldInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    testEquality(yieldAmount, stakeAmount, 'yieldAmount not eq');
  }

  function test_Should_unstake() public {
    YieldTestVars memory testVars;

    prepareDAI(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldSavingsDai.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    address yieldAccount = tsYieldSavingsDai.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    // add some yield
    uint256 deltaAmount = (stakeAmount * 35) / 1000;
    tsHEVM.prank(address(tsDepositor1));
    tsDAI.approve(address(tsSDAI), type(uint256).max);
    tsHEVM.prank(address(tsDepositor1));
    tsSDAI.rebase(yieldAccount, deltaAmount);

    (uint256 underAmount, uint256 yieldAmount) = tsYieldSavingsDai.getNftYieldInUnderlyingAsset(
      address(tsBAYC),
      tokenIds[0]
    );
    testEquality(underAmount, (stakeAmount + deltaAmount), 3, 'yieldAmount not eq');

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldSavingsDai.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, Constants.YIELD_STATUS_CLAIM, 'state not eq');
    assertEq(testVars.yieldAmount, yieldAmount, 'testVars.yieldAmount not eq');

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldSavingsDai.getNftUnstakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.unstakeFine, 0, 'unstakeFine not eq');
    assertEq(testVars.withdrawAmount, testVars.yieldAmount, 'withdrawAmount not eq');
    assertEq(testVars.withdrawReqId, 0, 'withdrawReqId not eq');
  }

  function test_Should_repay() public {
    YieldTestVars memory testVars;

    prepareDAI(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldSavingsDai.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.startPrank(address(tsBorrower1));

    tsYieldSavingsDai.createYieldAccount(address(tsBorrower1));
    tsYieldSavingsDai.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    // make some interest
    advanceTimes(365 days);

    tsYieldSavingsDai.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    tsDAI.approve(address(tsYieldSavingsDai), type(uint256).max);
    tsYieldSavingsDai.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    tsHEVM.stopPrank();

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldSavingsDai.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 0, 'state not eq');
    assertEq(testVars.debtAmount, 0, 'debtAmount not eq');
    assertEq(testVars.yieldAmount, 0, 'yieldAmount not eq');
  }

  function test_Should_unstakeAndRepay() public {
    YieldTestVars memory testVars;

    prepareDAI(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldSavingsDai.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.startPrank(address(tsBorrower1));

    tsYieldSavingsDai.createYieldAccount(address(tsBorrower1));
    tsYieldSavingsDai.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    // make some interest
    advanceTimes(365 days);

    tsDAI.approve(address(tsYieldSavingsDai), type(uint256).max);
    tsYieldSavingsDai.unstakeAndRepay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    tsHEVM.stopPrank();

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldSavingsDai.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 0, 'state not eq');
    assertEq(testVars.debtAmount, 0, 'debtAmount not eq');
    assertEq(testVars.yieldAmount, 0, 'yieldAmount not eq');
  }

  function test_Should_batch() public {
    YieldTestVars memory testVars;

    prepareDAI(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);
    address[] memory nfts = new address[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
      nfts[i] = address(tsBAYC);
    }

    uint256 stakeAmount = tsYieldSavingsDai.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 20) / 100;

    uint256[] memory stakeAmounts = new uint256[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
      stakeAmounts[i] = stakeAmount;
    }

    tsHEVM.startPrank(address(tsBorrower1));

    tsYieldSavingsDai.createYieldAccount(address(tsBorrower1));

    tsYieldSavingsDai.batchStake(tsCommonPoolId, nfts, tokenIds, stakeAmounts);

    // make some interest
    advanceTimes(365 days);

    tsYieldSavingsDai.batchUnstake(tsCommonPoolId, nfts, tokenIds, 0);

    for (uint i = 0; i < tokenIds.length; i++) {
      (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldSavingsDai.getNftUnstakeData(
        nfts[i],
        tokenIds[i]
      );
    }

    tsDAI.approve(address(tsYieldSavingsDai), type(uint256).max);
    tsYieldSavingsDai.batchRepay(tsCommonPoolId, nfts, tokenIds);

    tsHEVM.stopPrank();
  }

  function test_Should_collectFeeToTreasury() public {
    YieldTestVars memory testVars;

    prepareDAI(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldSavingsDai.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    address yieldAccount = tsYieldSavingsDai.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    // add some yield
    uint256 deltaAmount = (stakeAmount * 35) / 1000;
    tsHEVM.prank(address(tsDepositor1));
    tsDAI.approve(address(tsSDAI), type(uint256).max);
    tsHEVM.prank(address(tsDepositor1));
    tsSDAI.rebase(yieldAccount, deltaAmount);

    // drop down price
    adjustNftPrice(address(tsBAYC), 100);

    // ask bot to do the unstake forcely
    tsHEVM.prank(address(tsPoolAdmin));
    tsYieldSavingsDai.setBotAdmin(address(tsBorrower2));

    tsHEVM.prank(address(tsBorrower2));
    tsYieldSavingsDai.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 20e18);

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldSavingsDai.getNftUnstakeData(
      address(tsBAYC),
      tokenIds[0]
    );

    // do the repay
    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldSavingsDai.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 0, 'state not eq');

    // collect fee
    (testVars.totalFineBefore, testVars.claimedFine) = tsYieldSavingsDai.getTotalUnstakeFine();
    assertEq(testVars.claimedFine, 0, 'claimedFine not eq');

    tsHEVM.prank(address(tsPoolAdmin));
    tsYieldSavingsDai.collectFeeToTreasury();

    (testVars.totalFineAfter, testVars.claimedFine) = tsYieldSavingsDai.getTotalUnstakeFine();
    assertEq(testVars.totalFineAfter, testVars.totalFineBefore, 'totalFineAfter not eq');
    assertEq(testVars.claimedFine, testVars.totalFineBefore, 'claimedFine not eq');
  }

  function test_Should_unstake_bot() public {
    YieldTestVars memory testVars;

    prepareDAI(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldSavingsDai.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    // add some debt interest
    advanceTimes(360 days);

    // drop down price
    adjustNftPrice(address(tsBAYC), 100);

    // ask bot to do the unstake forcely
    tsHEVM.prank(address(tsPoolAdmin));
    tsYieldSavingsDai.setBotAdmin(address(tsBorrower2));

    tsHEVM.prank(address(tsBorrower2));
    tsYieldSavingsDai.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 20e18);

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldSavingsDai.getNftUnstakeData(
      address(tsBAYC),
      tokenIds[0]
    );

    // ask bot to do the repay
    tsHEVM.prank(address(tsBorrower2));
    tsYieldSavingsDai.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldSavingsDai.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, Constants.YIELD_STATUS_CLAIM, 'bot - state not eq');
    assertGt(testVars.debtAmount, 0, 'bot - debtAmount not gt');

    // owner to do the remain repay
    tsHEVM.prank(address(tsBorrower1));
    tsDAI.approve(address(tsYieldSavingsDai), type(uint256).max);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldSavingsDai.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldSavingsDai.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 0, 'owner - state not eq');
  }

  function adjustNftPrice(address nftAsset, uint256 percentage) internal {
    uint256 oldPrice = tsBendNFTOracle.getAssetPrice(nftAsset);
    uint256 newPrice = (oldPrice * percentage) / 1e4;
    tsBendNFTOracle.setAssetPrice(nftAsset, newPrice);
  }
}
