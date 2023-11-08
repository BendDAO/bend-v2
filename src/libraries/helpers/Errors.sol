// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Errors {
  // Common errors, 0~99
  string public constant CE_OK = '0';
  string public constant CE_INVALID_CALLER = '1';
  string public constant CE_ACL_ADMIN_CANNOT_BE_ZERO = '2';
  string public constant CE_ACL_MANAGER_CANNOT_BE_ZERO = '3';
  string public constant CE_PRICE_ORACLE_CANNOT_BE_ZERO = '3';
  string public constant CE_OWNER_CANNOT_BE_ZERO = '3';
  string public constant CE_INVALID_TRANSFER_AMOUNT = '20';
  string public constant CE_INVALID_SUPPLY_MODE = '21';
  string public constant CE_INVALID_SCALED_AMOUNT = '22';
  string public constant CE_INVALID_ASSET_TYPE = '23';
  string public constant CE_INVALID_POOL_ID = '24';
  string public constant CE_INVALID_GROUP_ID = '25';
  string public constant INVALID_ASSET_ID = '26';
  string public constant ASSET_NUMBER_EXCEED_MAX_LIMIT = '26';

  // Lending errors, 100~199
  string public constant PE_POOL_ALREADY_EXISTS = '100';
  string public constant PE_POOL_NOT_EXISTS = '101';
  string public constant PE_GROUP_ALREADY_EXISTS = '102';
  string public constant PE_GROUP_NOT_EXISTS = '103';
  string public constant PE_ASSET_ALREADY_EXISTS = '104';
  string public constant PE_ASSET_NOT_EXISTS = '105';
  string public constant PE_HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD = '106';
  string public constant LE_HEALTH_FACTOR_NOT_BELOW_THRESHOLD = '107';
  string public constant LE_CROSS_SUPPLY_NOT_EMPTY = '108';
  string public constant LE_ISOLATE_SUPPLY_NOT_EMPTY = '109';
  string public constant LE_CROSS_DEBT_NOT_EMPTY = '110';
  string public constant LE_ISOLATE_DEBT_NOT_EMPTY = '111';
  string public constant LE_ASSET_LIST_NOT_EMPTY = '112';
  string public constant LE_GROUP_LIST_NOT_EMPTY = '113';
}
