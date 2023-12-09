// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';
import 'src/libraries/helpers/Errors.sol';

import './TestWithIntegration.sol';

contract TestIntDepositERC20 is TestWithIntegration {
  function onSetUp() public virtual override {
    super.onSetUp();
  }

  function test_RevertIf_AmountZero() public {
    uint256 amount = 0 ether;

    tsDepositor1.approveERC20(address(tsWETH), 1);
    actionDepositERC20(address(tsDepositor1), tsCommonPoolId, address(tsWETH), amount, bytes(Errors.INVALID_AMOUNT));
  }

  function test_RevertIf_InsufficientAllowance() public {
    uint256 amount = 100 ether;

    tsDepositor1.approveERC20(address(tsWETH), 1);
    actionDepositERC20(
      address(tsDepositor1),
      tsCommonPoolId,
      address(tsWETH),
      amount,
      bytes('ERC20: insufficient allowance')
    );
  }

  function test_RevertIf_ExceedBalance() public {
    uint256 amount = 1_000_000_000 ether;

    tsDepositor1.approveERC20(address(tsWETH), amount);
    actionDepositERC20(
      address(tsDepositor1),
      tsCommonPoolId,
      address(tsWETH),
      amount,
      bytes('ERC20: transfer amount exceeds balance')
    );
  }

  function test_Should_Deposit_WETH() public {
    tsDepositor1.approveERC20(address(tsWETH), type(uint256).max);

    uint256 amount1 = 123 ether;
    actionDepositERC20(address(tsDepositor1), tsCommonPoolId, address(tsWETH), amount1, new bytes(0));

    advanceBlocks(100);

    uint256 amount2 = 45 ether;
    actionDepositERC20(address(tsDepositor1), tsCommonPoolId, address(tsWETH), amount2, new bytes(0));
  }

  function test_Should_Deposit_USDT() public {
    tsDepositor1.approveERC20(address(tsUSDT), type(uint256).max);

    uint256 amount1 = 543 * (10 ** tsUSDT.decimals());
    actionDepositERC20(address(tsDepositor1), tsCommonPoolId, address(tsUSDT), amount1, new bytes(0));

    advanceBlocks(100);

    uint256 amount2 = 21 * (10 ** tsUSDT.decimals());
    actionDepositERC20(address(tsDepositor1), tsCommonPoolId, address(tsUSDT), amount2, new bytes(0));
  }
}