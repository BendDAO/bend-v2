// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Strings.sol';

import 'test/setup/TestWithPrepare.sol';
import '@forge-std/Test.sol';

contract TestYieldEthStakingLido is TestWithPrepare {
  struct YieldTestVars {
    uint32 poolId;
    uint8 state;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 unstakeFine;
    uint256 withdrawAmount;
    uint256 withdrawReqId;
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

    uint256 stakeAmount = tsYieldEthStakingLido.getNftValueInETH(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    (testVars.poolId, testVars.state, testVars.debtShare, testVars.yieldShare) = tsYieldEthStakingLido.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.poolId, tsCommonPoolId, 'poolId not eq');
    assertEq(testVars.state, 1, 'state not eq');
    assertEq(testVars.debtShare, stakeAmount, 'debtShare not eq');
    assertEq(testVars.yieldShare, stakeAmount, 'yieldShare not eq');

    uint256 debtAmount = tsYieldEthStakingLido.getNftDebtInEth(address(tsBAYC), tokenIds[0]);
    assertEq(debtAmount, stakeAmount, 'debtAmount not eq');

    (uint256 yieldAmount, ) = tsYieldEthStakingLido.getNftYieldInEth(address(tsBAYC), tokenIds[0]);
    assertEq(yieldAmount, stakeAmount, 'yieldAmount not eq');
  }

  function test_Should_unstake() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingLido.getNftValueInETH(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    address yieldAccount = tsYieldEthStakingLido.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    uint256 deltaAmount = (stakeAmount * 35) / 1000;
    tsStETH.rebase{value: deltaAmount}(yieldAccount);

    (uint256 yieldAmount, ) = tsYieldEthStakingLido.getNftYieldInEth(address(tsBAYC), tokenIds[0]);
    testEquality(yieldAmount, (stakeAmount + deltaAmount), 'yieldAmount not eq');

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.poolId, testVars.state, testVars.debtShare, testVars.yieldShare) = tsYieldEthStakingLido.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 2, 'state not eq');

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldEthStakingLido.getNftUnstakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.unstakeFine, 0, 'unstakeFine not eq');
    assertEq(testVars.withdrawAmount, yieldAmount, 'withdrawAmount not eq');
    assertGt(testVars.withdrawReqId, 0, 'withdrawReqId not gt');
  }

  function test_Should_repay() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingLido.getNftValueInETH(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.createYieldAccount(address(tsBorrower1));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.unstakeFine, testVars.withdrawAmount, testVars.withdrawReqId) = tsYieldEthStakingLido.getNftUnstakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    tsUnstETH.setWithdrawalStatus(testVars.withdrawReqId, true, false);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.repay(tsCommonPoolId, address(tsBAYC), tokenIds[0]);

    (testVars.poolId, testVars.state, testVars.debtShare, testVars.yieldShare) = tsYieldEthStakingLido.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 0, 'state not eq');
    assertEq(testVars.debtShare, 0, 'debtShare not eq');
    assertEq(testVars.yieldShare, 0, 'yieldShare not eq');
  }
}
