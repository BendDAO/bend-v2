// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Constants {
  // Asset type
  uint256 public constant ASSET_TYPE_ERC20 = 1;
  uint256 public constant ASSET_TYPE_ERC721 = 2;

  // Supply Mode
  uint256 public constant SUPPLY_MODE_CROSS = 1;
  uint256 public constant SUPPLY_MODE_ISOLATE = 2;
}
