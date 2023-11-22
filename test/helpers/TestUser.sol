// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import 'src/PoolManager.sol';

contract TestUser {
  using SafeERC20 for ERC20;

  PoolManager internal _poolManager;
  uint256 internal _uid;
  uint256[] internal _tokenIds;

  constructor(PoolManager poolManager_, uint256 uid_) {
    _poolManager = poolManager_;
    _uid = uid_;
    _tokenIds = new uint256[](3);
    for (uint i = 0; i < 3; i++) {
      _tokenIds[i] = uid_ + i;
    }
  }

  receive() external payable {}

  function getUID() public view returns (uint256) {
    return _uid;
  }

  function getTokenIds() public view returns (uint256[] memory) {
    return _tokenIds;
  }

  function balanceOf(address token) external view returns (uint256) {
    return ERC20(token).balanceOf(address(this));
  }

  function approveERC20(address token, uint256 amount) external {
    ERC20(token).safeApprove(address(_poolManager), amount);
  }

  function approveERC20(address token, address spender, uint256 amount) external {
    ERC20(token).safeApprove(spender, amount);
  }

  function approveERC721(address token, uint256 tokenId) external {
    ERC721(token).approve(address(_poolManager), tokenId);
  }

  function approveERC721(address token, address spender, uint256 tokenId) external {
    ERC721(token).approve(spender, tokenId);
  }

  function setApprovalForAllERC721(address token) external {
    ERC721(token).setApprovalForAll(address(_poolManager), true);
  }

  function setApprovalForAllERC721(address token, address spender) external {
    ERC721(token).setApprovalForAll(spender, true);
  }

  function depositERC20(uint32 poolId, address asset, uint256 amount) public {
    _poolManager.depositERC20(poolId, asset, amount);
  }

  function depositERC721(uint32 poolId, address asset, uint256[] calldata tokenIds, uint8 supplyMode) public {
    _poolManager.depositERC721(poolId, asset, tokenIds, supplyMode);
  }

  function borrowERC20(uint32 poolId, address asset, uint8 group, uint256 amount, address to) public {
    _poolManager.borrowERC20(poolId, asset, group, amount, to);
  }

  function repayERC20(uint32 poolId, address asset, uint8 group, uint256 amount) public {
    _poolManager.repayERC20(poolId, asset, group, amount);
  }
}
