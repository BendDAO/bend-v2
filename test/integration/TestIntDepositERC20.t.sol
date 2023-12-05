// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import './TestWithIntegration.sol';

contract TestIntDepositERC20 is TestWithIntegration {
  function onSetUp() public virtual override {
    super.onSetUp();
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

  function test_RevertIf_InsufficientBalance() public {
    uint256 amount = 100000 ether;

    tsDepositor1.approveERC20(address(tsWETH), 1);
    actionDepositERC20(
      address(tsDepositor1),
      tsCommonPoolId,
      address(tsWETH),
      amount,
      bytes('ERC20: insufficient allowance')
    );
  }

  function test_Should_Deposit_WETH() public {
    uint256 amount = 100 ether;

    tsDepositor1.approveERC20(address(tsWETH), amount);
    actionDepositERC20(address(tsDepositor1), tsCommonPoolId, address(tsWETH), amount, new bytes(0));
  }

  function test_Should_Deposit_USDT() public {
    uint256 amount = 100 * (10 ** tsUSDT.decimals());

    tsDepositor1.approveERC20(address(tsUSDT), amount);
    actionDepositERC20(address(tsDepositor1), tsCommonPoolId, address(tsUSDT), amount, new bytes(0));
  }
}
