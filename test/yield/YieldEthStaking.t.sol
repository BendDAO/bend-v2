// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Strings.sol';

import 'test/setup/TestWithPrepare.sol';
import '@forge-std/Test.sol';

contract TestYieldEthStaking is TestWithPrepare {
  struct YieldTestVars {
    uint32 poolId;
    uint8 state;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 unstakeFine;
    uint256 stEthWithdrawAmount;
    uint256 stEthWithdrawReqId;
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

    (uint256 stETHAmount, ) = tsYieldEthStakingLido.getNftYieldInEth(address(tsBAYC), tokenIds[0]);
    assertEq(stETHAmount, stakeAmount, 'stETHAmount not lt');
  }

  function test_Should_unstake() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingLido.getNftValueInETH(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    (uint256 stETHAmount, ) = tsYieldEthStakingLido.getNftYieldInEth(address(tsBAYC), tokenIds[0]);

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.poolId, testVars.state, testVars.debtShare, testVars.yieldShare) = tsYieldEthStakingLido.getNftStakeData(
      address(tsBAYC),
      tokenIds[0]
    );
    assertEq(testVars.state, 2, 'state not eq');

    (testVars.unstakeFine, testVars.stEthWithdrawAmount, testVars.stEthWithdrawReqId) = tsYieldEthStakingLido
      .getNftUnstakeData(address(tsBAYC), tokenIds[0]);
    assertEq(testVars.unstakeFine, 0, 'state not eq');
    assertEq(testVars.stEthWithdrawAmount, stETHAmount, 'stEthWithdrawAmount not eq');
    assertGt(testVars.stEthWithdrawReqId, 0, 'stEthWithdrawReqId not gt');
  }

  function test_Should_repay() public {
    YieldTestVars memory testVars;

    prepareWETH(tsDepositor1);

    uint256[] memory tokenIds = prepareIsolateBAYC(tsBorrower1);

    uint256 stakeAmount = tsYieldEthStakingLido.getNftValueInETH(address(tsBAYC));
    stakeAmount = (stakeAmount * 80) / 100;

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.stake(tsCommonPoolId, address(tsBAYC), tokenIds[0], stakeAmount);

    tsHEVM.prank(tsStETH.owner());
    tsStETH.transferETH(address(tsUnstETH));

    tsHEVM.prank(address(tsBorrower1));
    tsYieldEthStakingLido.unstake(tsCommonPoolId, address(tsBAYC), tokenIds[0], 0);

    (testVars.unstakeFine, testVars.stEthWithdrawAmount, testVars.stEthWithdrawReqId) = tsYieldEthStakingLido
      .getNftUnstakeData(address(tsBAYC), tokenIds[0]);
    tsUnstETH.setWithdrawalStatus(testVars.stEthWithdrawReqId, true, false);

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
