// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import './Storage.sol';

contract PoolManager is Storage {
  function createPool() public returns (uint256 poolId) {}

  function createGroup(uint256 poolId) public returns (uint256 groupId) {}

  function addAsset() public {}

  function deleteAsset() public {}

  function depositERC20(uint256 asset, uint256 amount, address onBehalfOf) public {}

  function withdrawERC20(uint256 asset, uint256 amount, address to) public {}

  function depositERC721(uint256 asset, uint256[] calldata tokenIds, uint256 supplyMode, address onBehalfOf) public {}

  function withdrawERC721(uint256 asset, uint256[] calldata tokenIds, address to) public {}

  function borrowERC20(uint256 asset, uint256 amount, address onBehalfOf) public {}

  function repayERC20(uint256 asset, uint256 amount, address onBehalfOf) public {}
}
