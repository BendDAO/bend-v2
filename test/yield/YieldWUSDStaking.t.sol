// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {IWUSDStaking} from 'src/yield/wusd/IWUSDStaking.sol';

import 'test/setup/TestWithPrepare.sol';
import '@forge-std/Test.sol';

contract TestYieldWUSDStaking is TestWithPrepare {
  struct YieldTestVars {
    uint32 poolId;
    uint8 state;
    uint256 debtAmount;
    uint256 yieldAmount;
    uint256 unstakeFine;
    uint256 withdrawAmount;
    uint256 withdrawReqId;
  }

  uint256 wusdStakingPoolId;

  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();

    initPoolWUSD(tsCommonPoolId);
    initYieldWUSDStaking(tsCommonPoolId);

    wusdStakingPoolId = 2;
  }

  function test_Should_stake() public {
    YieldTestVars memory testVars;

    prepareWUSD(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldWUSDStaking.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount, wusdStakingPoolId);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldWUSDStaking.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.poolId, tsCommonPoolId, 'poolId not eq');
    assertEq(testVars.state, Constants.YIELD_STATUS_ACTIVE, 'state not eq');
    testEquality(testVars.debtAmount, stakeAmount, 'debtAmount not eq');
    testEquality(testVars.yieldAmount, stakeAmount, 'yieldAmount not eq');

    uint256 debtAmount = tsYieldWUSDStaking.getNftDebtInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    testEquality(debtAmount, stakeAmount, 'debtAmount not eq');

    (uint256 yieldAmount, ) = tsYieldWUSDStaking.getNftYieldInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    testEquality(yieldAmount, stakeAmount, 'yieldAmount not eq');
  }

  function test_Should_unstake_before_mature() public {
    YieldTestVars memory testVars;

    prepareWUSD(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldWUSDStaking.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount, wusdStakingPoolId);

    // make some yield
    IWUSDStaking.StakingPool memory stakingPool = tsWUSDStaking.getStakingPoolDetails(wusdStakingPoolId);
    advanceTimes(stakingPool.stakingPeriod - 1 days);

    (uint256 yieldAmount, ) = tsYieldWUSDStaking.getNftYieldInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    assertGt(yieldAmount, stakeAmount, 'yieldAmount not gt');

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldWUSDStaking.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, Constants.YIELD_STATUS_UNSTAKE, 'state not eq');

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldWUSDStaking.getNftUnstakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.unstakeFine, 0, 'unstakeFine not eq');
    assertGt(testVars.withdrawAmount, 0, 'withdrawAmount not gt 0');
    assertLe(testVars.withdrawAmount, yieldAmount, 'withdrawAmount not lt');
    assertGt(testVars.withdrawReqId, 0, 'withdrawReqId not gt');
  }

  function test_Should_repay_before_mature() public {
    YieldTestVars memory testVars;

    prepareWUSD(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldWUSDStaking.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount, wusdStakingPoolId);

    // make some yield
    IWUSDStaking.StakingPool memory stakingPool = tsWUSDStaking.getStakingPoolDetails(wusdStakingPoolId);
    advanceTimes(stakingPool.stakingPeriod - 1 days);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    // cooldown duration
    advanceTimes(tsWUSDStaking.getCooldownDuration());

    tsDepositor1.transferERC20(address(tsWUSD), address(tsWUSDStaking), 100_000e6);

    // tsHEVM.prank(address(tsBorrower1));
    // tsWUSD.approve(address(tsYieldWUSDStaking), type(uint256).max);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldWUSDStaking.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 0, 'state not eq');
    assertEq(testVars.debtAmount, 0, 'debtAmount not eq');
    assertEq(testVars.yieldAmount, 0, 'yieldAmount not eq');
  }

  function test_Should_unstake_after_mature() public {
    YieldTestVars memory testVars;

    prepareWUSD(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldWUSDStaking.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount, wusdStakingPoolId);

    // make some yield
    IWUSDStaking.StakingPool memory stakingPool = tsWUSDStaking.getStakingPoolDetails(wusdStakingPoolId);
    advanceTimes(stakingPool.stakingPeriod + 1 days);

    (uint256 yieldAmount, ) = tsYieldWUSDStaking.getNftYieldInUnderlyingAsset(address(tsBAYC), tokenIds[0]);
    assertGt(yieldAmount, stakeAmount, 'yieldAmount not gt');

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldWUSDStaking.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, Constants.YIELD_STATUS_CLAIM, 'state not eq');

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldWUSDStaking.getNftUnstakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.unstakeFine, 0, 'unstakeFine not eq');
    assertGt(testVars.withdrawAmount, 0, 'withdrawAmount not gt 0');
    assertLe(testVars.withdrawAmount, yieldAmount, 'withdrawAmount not lt');
    assertGt(testVars.withdrawReqId, 0, 'withdrawReqId not gt');
  }

  function test_Should_repay_after_mature() public {
    YieldTestVars memory testVars;

    prepareWUSD(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldWUSDStaking.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount, wusdStakingPoolId);

    // make some yield
    IWUSDStaking.StakingPool memory stakingPool = tsWUSDStaking.getStakingPoolDetails(wusdStakingPoolId);
    advanceTimes(stakingPool.stakingPeriod + 1 days);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    // cooldown duration
    advanceTimes(tsWUSDStaking.getCooldownDuration());

    tsDepositor1.transferERC20(address(tsWUSD), address(tsWUSDStaking), 100_000e6);

    // tsHEVM.prank(address(tsBorrower1));
    // tsWUSD.approve(address(tsYieldWUSDStaking), type(uint256).max);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldWUSDStaking.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 0, 'state not eq');
    assertEq(testVars.debtAmount, 0, 'debtAmount not eq');
    assertEq(testVars.yieldAmount, 0, 'yieldAmount not eq');
  }

  function test_Should_batch() public {
    prepareWUSD(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);
    address[] memory nfts = new address[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
      nfts[i] = address(tsBAYC);
    }

    uint256 stakeAmount = tsYieldWUSDStaking.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    uint256[] memory stakeAmounts = new uint256[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
      stakeAmounts[i] = stakeAmount;
    }

    tsHEVM.startPrank(address(tsBorrower1));

    tsYieldWUSDStaking.createYieldAccount(address(tsBorrower1));

    tsYieldWUSDStaking.batchStake(tsCommonPoolId, nfts, tokenIds, stakeAmounts, wusdStakingPoolId);

    // make some yield
    IWUSDStaking.StakingPool memory stakingPool = tsWUSDStaking.getStakingPoolDetails(wusdStakingPoolId);
    advanceTimes(stakingPool.stakingPeriod - 1 days);

    tsYieldWUSDStaking.batchUnstake(tsCommonPoolId, nfts, tokenIds, 0);

    // cooldown duration
    advanceTimes(tsWUSDStaking.getCooldownDuration());

    tsDepositor1.transferERC20(address(tsWUSD), address(tsWUSDStaking), 100_000e6);

    tsWETH.approve(address(tsYieldWUSDStaking), type(uint256).max);

    tsYieldWUSDStaking.batchRepay(tsCommonPoolId, nfts, tokenIds);

    tsHEVM.stopPrank();
  }

  function test_Should_unstake_bot() public {
    YieldTestVars memory testVars;

    prepareWUSD(tsDepositor1);

    // try to make yeild apr less than debt borrow rate
    tsWUSDStaking.setBasicAPY(100);
    tsWUSDStaking.updateStakingPoolAPY(wusdStakingPoolId, 100);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldWUSDStaking.getNftValueInUnderlyingAsset(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount, wusdStakingPoolId);

    // add some debt interest
    IWUSDStaking.StakingPool memory stakingPool = tsWUSDStaking.getStakingPoolDetails(wusdStakingPoolId);
    advanceTimes(stakingPool.stakingPeriod - 1 days);

    // drop down price
    adjustNftPrice(address(tsBAYC), 100);

    // ask bot to do the unstake forcely
    tsHEVM.prank(address(tsPoolAdmin));
    tsYieldWUSDStaking.setBotAdmin(address(tsBorrower2));

    tsHEVM.prank(address(tsBorrower2));
    tsYieldWUSDStaking.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 20e6);

    advanceTimes(tsWUSDStaking.getCooldownDuration());

    tsDepositor1.transferERC20(address(tsWUSD), address(tsWUSDStaking), 100_000e6);

    // ask bot to do the repay
    tsHEVM.prank(address(tsBorrower2));
    tsYieldWUSDStaking.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldWUSDStaking.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, Constants.YIELD_STATUS_CLAIM, 'bot - state not eq');
    assertGt(testVars.debtAmount, 0, 'bot - debtAmount not gt');

    // owner to do the remain repay
    tsHEVM.prank(address(tsBorrower1));
    tsWUSD.approve(address(tsYieldWUSDStaking), type(uint256).max);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldWUSDStaking.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtAmount, testVars.yieldAmount) = tsYieldWUSDStaking.getNftStakeData(
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
