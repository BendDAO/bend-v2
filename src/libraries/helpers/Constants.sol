// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Constants {
  // Asset type
  uint256 public constant ASSET_TYPE_ERC20 = 1;
  uint256 public constant ASSET_TYPE_ERC721 = 2;

  // Supply Mode
  uint256 public constant SUPPLY_MODE_CROSS = 1;
  uint256 public constant SUPPLY_MODE_ISOLATE = 2;
  uint256 public constant SUPPLY_MODE_YIELD = 3;

  // Minimum health factor allowed under any circumstance
  // A value of 0.95e18 results in 0.95
  uint256 public constant MINIMUM_HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 0.95e18;

  /**
   * @dev Minimum health factor to consider a user position healthy
   * A value of 1e18 results in 1
   */
  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
}
