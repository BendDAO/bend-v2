// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import 'src/PoolManager.sol';

contract User {
  using SafeERC20 for ERC20;

  PoolManager internal poolManager;

  constructor(PoolManager _poolManager) {
    poolManager = _poolManager;
  }

  receive() external payable {}

  function balanceOf(address _token) external view returns (uint256) {
    return ERC20(_token).balanceOf(address(this));
  }

  function approve(address _token, uint256 _amount) external {
    ERC20(_token).safeApprove(address(poolManager), _amount);
  }

  function approve(address _token, address _spender, uint256 _amount) external {
    ERC20(_token).safeApprove(_spender, _amount);
  }

  function depositERC20(uint32 poolId, address asset, uint256 amount) public {
    poolManager.depositERC20(poolId, asset, amount);
  }
}
