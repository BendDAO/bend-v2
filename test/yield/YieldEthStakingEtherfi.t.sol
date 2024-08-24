// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';

import 'test/setup/TestWithPrepare.sol';
import '@forge-std/Test.sol';

contract TestYieldEthStakingEtherfi is TestWithPrepare {
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

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    (, , uint256 stakeAmount) = tsYieldEthStakingEtherfi.getNftCollateralData(address(tsBAYC), tokenIds[0]);
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldEthStakingEtherfi
      .getNftStakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.poolId, tsCommonPoolId, 'poolId not eq');
    assertEq(testVars.state, Constants.YIELD_STATUS_ACTIVE, 'state not eq');
    testEquality(testVars.debtAmount, stakeAmount, 'debtAmount not eq');
    testEquality(testVars.yieldAmount, stakeAmount, 'yieldAmount not eq');

    uint256 debtAmount = tsYieldEthStakingEtherfi.getNftDebtInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    testEquality(debtAmount, stakeAmount, 'debtAmount not eq');

    (uint256 yieldAmount, ) = tsYieldEthStakingEtherfi.getNftYieldInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    testEquality(yieldAmount, stakeAmount, 'yieldAmount not eq');

    tsYieldEthStakingEtherfi.getNftCollateralData(address(tsBAYC), tokenIds[0]);
  }

  function test_Should_unstake() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingEtherfi.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    address yieldAccount = tsYieldEthStakingEtherfi.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    uint256 deltaAmount = (stakeAmount * 35) / 1000;
    tsEtherfiLiquidityPool.rebase{value: deltaAmount}(yieldAccount);

    (uint256 yieldAmount, ) = tsYieldEthStakingEtherfi.getNftYieldInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    assertApproxEqAbs(yieldAmount, (stakeAmount + deltaAmount), 3, 'yieldAmount not eq');

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldEthStakingEtherfi
      .getNftStakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.state, Constants.YIELD_STATUS_UNSTAKE, 'state not eq');

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldEthStakingEtherfi
      .getNftUnstakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.unstakeFine, 0, 'state not eq');
    assertEq(testVars.withdrawAmount, yieldAmount, 'withdrawAmount not eq');
    assertGt(testVars.withdrawReqId, 0, 'withdrawReqId not gt');
  }

  function test_Should_repay() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingEtherfi.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    advanceTimes(7 days); // accure some debt but without any yield

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldEthStakingEtherfi
      .getNftUnstakeData(address(tsBAYC), tokenIds[0]);
    tsEtherfiWithdrawRequestNFT.setWithdrawalStatus(testVars.withdrawReqId, true, false);

    tsHEVM.prank(address(tsBorrower1));
    tsWETH.approve(address(tsYieldEthStakingEtherfi), type(uint256).max);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldEthStakingEtherfi
      .getNftStakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.state, 0, 'state not eq');
    assertEq(testVars.debtAmount, 0, 'debtAmount not eq');
    assertEq(testVars.yieldAmount, 0, 'yieldAmount not eq');
  }

  function test_Should_collectFeeToTreasury() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingEtherfi.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    address yieldAccount = tsYieldEthStakingEtherfi.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    // add some yield
    uint256 deltaAmount = (stakeAmount * 35) / 1000;
    tsEtherfiLiquidityPool.rebase{value: deltaAmount}(yieldAccount);

    // drop down price
    adjustNftPrice(address(tsBAYC), 100);

    // ask bot to do the unstake forcely
    tsHEVM.prank(address(tsPoolAdmin));
    tsYieldEthStakingEtherfi.setBotAdmin(address(tsBorrower2));

    tsHEVM.prank(address(tsBorrower2));
    tsYieldEthStakingEtherfi.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0.001 ether);

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldEthStakingEtherfi
      .getNftUnstakeData(address(tsBAYC), tokenIds[0]);
    tsEtherfiWithdrawRequestNFT.setWithdrawalStatus(testVars.withdrawReqId, true, false);

    // do the repay
    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldEthStakingEtherfi
      .getNftStakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.state, 0, 'state not eq');

    // collect fee
    (testVars.totalFineBefore, testVars.claimedFine) = tsYieldEthStakingEtherfi.getTotalUnstakeFine();
    assertEq(testVars.claimedFine, 0, 'claimedFine not eq');

    tsHEVM.prank(address(tsPoolAdmin));
    tsYieldEthStakingEtherfi.collectFeeToTreasury();

    (testVars.totalFineAfter, testVars.claimedFine) = tsYieldEthStakingEtherfi.getTotalUnstakeFine();
    assertEq(testVars.totalFineAfter, testVars.totalFineBefore, 'totalFineAfter not eq');
    assertEq(testVars.claimedFine, testVars.totalFineBefore, 'claimedFine not eq');
  }

  function test_Should_unstake_bot() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingEtherfi.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    // add some debt interest
    advanceTimes(360 days);

    // drop down price
    adjustNftPrice(address(tsBAYC), 100);

    // ask bot to do the unstake forcely
    tsHEVM.prank(address(tsPoolAdmin));
    tsYieldEthStakingEtherfi.setBotAdmin(address(tsBorrower2));

    tsHEVM.prank(address(tsBorrower2));
    tsYieldEthStakingEtherfi.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0.001 ether);

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldEthStakingEtherfi
      .getNftUnstakeData(address(tsBAYC), tokenIds[0]);
    tsEtherfiWithdrawRequestNFT.setWithdrawalStatus(testVars.withdrawReqId, true, false);

    // ask bot to do the repay
    tsHEVM.prank(address(tsBorrower2));
    tsYieldEthStakingEtherfi.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldEthStakingEtherfi
      .getNftStakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.state, Constants.YIELD_STATUS_CLAIM, 'bot - state not eq');
    assertGt(testVars.debtAmount, 0, 'bot - debtAmount not gt');

    // owner to do the remain repay
    tsHEVM.prank(address(tsBorrower1));
    tsWETH.approve(address(tsYieldEthStakingEtherfi), type(uint256).max);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingEtherfi.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldEthStakingEtherfi
      .getNftStakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.state, 0, 'owner - state not eq');
  }

  function adjustNftPrice(address nftAsset, uint256 percentage) internal {
    uint256 oldPrice = tsBendNFTOracle.getAssetPrice(nftAsset);
    uint256 newPrice = (oldPrice * percentage) / 1e4;
    tsBendNFTOracle.setAssetPrice(nftAsset, newPrice);
  }
}
