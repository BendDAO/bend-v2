// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

interface IWETH is IERC20Metadata {
  function deposit() external payable;

  function withdraw(uint256) external;
}
