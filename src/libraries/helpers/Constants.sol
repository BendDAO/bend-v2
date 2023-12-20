// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Constants {
  uint32 public constant INITIAL_POOL_ID = 1;

  // Asset params
  uint16 public constant MAX_COLLATERAL_FACTOR = 10000;
  uint16 public constant MAX_LIQUIDATION_THRESHOLD = 10000;
  uint16 public constant MAX_LIQUIDATION_BONUS = 10000;
  uint16 public constant MAX_FEE_FACTOR = 10000;
  uint16 public constant MAX_REDEEM_THRESHOLD = 10000;
  uint16 public constant MAX_BIDFINE_FACTOR = 10000;
  uint16 public constant MAX_MIN_BIDFINE_FACTOR = 10000;
  uint40 public constant MAX_AUCTION_DUARATION = 7 days;

  uint16 public constant MAX_NUMBER_OF_ASSET = 256;

  uint8 public constant MAX_NUMBER_OF_GROUP = 4;
  uint8 public constant GROUP_ID_INVALID = 255;
  uint8 public constant GROUP_ID_YIELD = 0;
  uint8 public constant GROUP_ID_LEND_MIN = 1;
  uint8 public constant GROUP_ID_LEND_MAX = 3;

  // Asset type
  uint8 public constant ASSET_TYPE_ERC20 = 1;
  uint8 public constant ASSET_TYPE_ERC721 = 2;

  // Supply Mode
  uint8 public constant SUPPLY_MODE_CROSS = 1;
  uint8 public constant SUPPLY_MODE_ISOLATE = 2;
  uint8 public constant SUPPLY_MODE_YIELD = 3;

  // Asset Lock Flag
  uint16 public constant ASSET_LOCK_FLAG_CROSS = 0x0001; // not used
  uint16 public constant ASSET_LOCK_FLAG_ISOLATE = 0x0002; // not used
  uint16 public constant ASSET_LOCK_FLAG_YIELD = 0x0004;

  // Loan Status
  uint8 public constant LOAN_STATUS_ACTIVE = 1;
  uint8 public constant LOAN_STATUS_REPAID = 2;
  uint8 public constant LOAN_STATUS_AUCTION = 3;
  uint8 public constant LOAN_STATUS_DEFAULT = 4;

  // Minimum health factor allowed under any circumstance
  // A value of 0.95e18 results in 0.95
  uint256 public constant MINIMUM_HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 0.95e18;

  /**
   * @dev Minimum health factor to consider a user position healthy
   * A value of 1e18 results in 1
   */
  uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

  /**
   * @dev Default percentage of borrower's debt to be repaid in a liquidation.
   * @dev Percentage applied when the users health factor is above `CLOSE_FACTOR_HF_THRESHOLD`
   * Expressed in bps, a value of 0.5e4 results in 50.00%
   */
  uint256 internal constant DEFAULT_LIQUIDATION_CLOSE_FACTOR = 0.5e4;

  /**
   * @dev Maximum percentage of borrower's debt to be repaid in a liquidation
   * @dev Percentage applied when the users health factor is below `CLOSE_FACTOR_HF_THRESHOLD`
   * Expressed in bps, a value of 1e4 results in 100.00%
   */
  uint256 public constant MAX_LIQUIDATION_CLOSE_FACTOR = 1e4;

  /**
   * @dev This constant represents below which health factor value it is possible to liquidate
   * an amount of debt corresponding to `MAX_LIQUIDATION_CLOSE_FACTOR`.
   * A value of 0.95e18 results in 0.95
   */
  uint256 public constant CLOSE_FACTOR_HF_THRESHOLD = 0.95e18;
}
