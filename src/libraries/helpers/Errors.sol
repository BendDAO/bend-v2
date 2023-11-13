// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Errors {
  // Common errors, 0~99
  string public constant OK = '0';
  string public constant INVALID_CALLER = '1';
  string public constant ACL_ADMIN_CANNOT_BE_ZERO = '2';
  string public constant ACL_MANAGER_CANNOT_BE_ZERO = '3';
  string public constant OWNER_CANNOT_BE_ZERO = '3';
  string public constant CALLER_NOT_ORACLE_ADMIN = '4';
  string public constant INVALID_TRANSFER_AMOUNT = '20';
  string public constant INVALID_SUPPLY_MODE = '21';
  string public constant INVALID_SCALED_AMOUNT = '22';
  string public constant INVALID_ASSET_TYPE = '23';
  string public constant INVALID_POOL_ID = '24';
  string public constant INVALID_GROUP_ID = '25';
  string public constant INVALID_ASSET_ID = '26';
  string public constant INCONSISTENT_PARAMS_LENGTH = '27';

  // Lending errors, 100~199
  string public constant POOL_ALREADY_EXISTS = '100';
  string public constant POOL_NOT_EXISTS = '101';
  string public constant GROUP_ALREADY_EXISTS = '110';
  string public constant GROUP_NOT_EXISTS = '111';
  string public constant GROUP_LIST_NOT_EMPTY = '112';
  string public constant GROUP_NUMBER_EXCEED_MAX_LIMIT = '113';
  string public constant ASSET_ALREADY_EXISTS = '120';
  string public constant ASSET_NOT_EXISTS = '121';
  string public constant ASSET_LIST_NOT_EMPTY = '122';
  string public constant ASSET_NUMBER_EXCEED_MAX_LIMIT = '123';
  string public constant ASSET_AGGREGATOR_NOT_EXIST = '124';
  string public constant ASSET_PRICE_IS_ZERO = '125';

  string public constant HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD = '106';
  string public constant HEALTH_FACTOR_NOT_BELOW_THRESHOLD = '107';
  string public constant CROSS_SUPPLY_NOT_EMPTY = '108';
  string public constant ISOLATE_SUPPLY_NOT_EMPTY = '109';
  string public constant CROSS_DEBT_NOT_EMPTY = '110';
  string public constant ISOLATE_DEBT_NOT_EMPTY = '111';
}
