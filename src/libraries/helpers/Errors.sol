// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Errors {
  string public constant OK = '0';
  string public constant INVALID_AMOUNT = '100';
  string public constant INVALID_SCALED_AMOUNT = '101';
  string public constant INVALID_TRANSFER_AMOUNT = '102';
  string public constant INVALID_ADDRESS = '103';
  string public constant INVALID_FROM_ADDRESS = '104';
  string public constant INVALID_TO_ADDRESS = '105';
  string public constant INVALID_SUPPLY_MODE = '106';
  string public constant INVALID_ASSET_TYPE = '107';
  string public constant INVALID_POOL_ID = '108';
  string public constant INVALID_GROUP_ID = '109';
  string public constant INVALID_ASSET_ID = '110';
  string public constant INVALID_ASSET_DECIMALS = '111';
  string public constant INVALID_IRM_ADDRESS = '112';
  string public constant INVALID_CALLER = '113';
  string public constant INVALID_ID_LIST = '114';
  string public constant INVALID_COLLATERAL_AMOUNT = '115';
  string public constant INVALID_DEBT_AMOUNT = '116';
  string public constant INVALID_TOKEN_OWNER = '117';
  string public constant INVALID_YIELD_STAKER = '118';
  string public constant INCONSISTENT_PARAMS_LENGH = '119';
  string public constant INVALID_LOAN_STATUS = '120';

  string public constant ENUM_SET_ADD_FAILED = '150';
  string public constant ENUM_SET_REMOVE_FAILED = '151';

  string public constant ACL_ADMIN_CANNOT_BE_ZERO = '200';
  string public constant ACL_MANAGER_CANNOT_BE_ZERO = '201';
  string public constant OWNER_CANNOT_BE_ZERO = '202';
  string public constant CALLER_NOT_ORACLE_ADMIN = '203';
  string public constant INCONSISTENT_PARAMS_LENGTH = '204';
  string public constant INVALID_ASSET_PARAMS = '205';
  string public constant CALLER_NOT_EMERGENCY_ADMIN = '206';

  string public constant POOL_ALREADY_EXISTS = '300';
  string public constant POOL_NOT_EXISTS = '301';
  string public constant POOL_YIELD_ALREADY_ENABLE = '303';
  string public constant POOL_YIELD_NOT_ENABLE = '304';
  string public constant POOL_YIELD_IS_PAUSED = '305';

  string public constant GROUP_ALREADY_EXISTS = '320';
  string public constant GROUP_NOT_EXISTS = '321';
  string public constant GROUP_LIST_NOT_EMPTY = '322';
  string public constant GROUP_LIST_IS_EMPTY = '323';
  string public constant GROUP_NUMBER_EXCEED_MAX_LIMIT = '324';
  string public constant GROUP_USDED_BY_ASSET = '325';

  string public constant ASSET_ALREADY_EXISTS = '340';
  string public constant ASSET_NOT_EXISTS = '341';
  string public constant ASSET_LIST_NOT_EMPTY = '342';
  string public constant ASSET_NUMBER_EXCEED_MAX_LIMIT = '343';
  string public constant ASSET_AGGREGATOR_NOT_EXIST = '344';
  string public constant ASSET_PRICE_IS_ZERO = '345';
  string public constant ASSET_TYPE_NOT_ERC20 = '346';
  string public constant ASSET_TYPE_NOT_ERC721 = '347';
  string public constant ASSET_NOT_ACTIVE = '348';
  string public constant ASSET_IS_PAUSED = '349';
  string public constant ASSET_IS_FROZEN = '350';
  string public constant ASSET_IS_BORROW_DISABLED = '351';
  string public constant ASSET_NOT_CROSS_MODE = '352';
  string public constant ASSET_NOT_ISOLATE_MODE = '353';
  string public constant ASSET_YIELD_ALREADY_ENABLE = '354';
  string public constant ASSET_YIELD_NOT_ENABLE = '355';
  string public constant ASSET_YIELD_IS_PAUSED = '356';

  string public constant HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD = '400';
  string public constant HEALTH_FACTOR_NOT_BELOW_THRESHOLD = '401';
  string public constant CROSS_SUPPLY_NOT_EMPTY = '402';
  string public constant ISOLATE_SUPPLY_NOT_EMPTY = '403';
  string public constant CROSS_BORROW_NOT_EMPTY = '404';
  string public constant ISOLATE_BORROW_NOT_EMPTY = '405';
  string public constant COLLATERAL_BALANCE_IS_ZERO = '406';
  string public constant BORROW_BALANCE_IS_ZERO = '407';
  string public constant LTV_VALIDATION_FAILED = '408';
  string public constant COLLATERAL_CANNOT_COVER_NEW_BORROW = '409';
  string public constant LIQUIDATE_REPAY_DEBT_FAILED = '410';

  string public constant YIELD_EXCEED_CAP_LIMIT = '500';

  string public constant ISOLATE_LOAN_ASSET_NOT_MATCH = '600';
  string public constant ISOLATE_LOAN_GROUP_NOT_MATCH = '601';
  string public constant ISOLATE_LOAN_BORROWER_NOT_MATCH = '602';
}
