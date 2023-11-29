// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

/**
 * @title IEscrowAccount
 * @notice Defines the basic interface for the Escrow Account
 */
interface IEscrowAccount {
  function transferERC20(address token, address to, uint256 amount) external;

  function transferERC721(address token, address to, uint256 tokenId) external;

  function batchTransferERC721(address token, address to, uint256[] calldata tokenIds) external;
}
