// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Errors {
  // Common errors, 0~99
  string public constant CE_OK = '0';
  string public constant CE_INVALID_CALLER = '1';
  string public constant CE_INVALID_TRANSFER_AMOUNT = '2';
  string public constant CE_INVALID_SUPPLY_MODE = '3';

  // Pool errors, 100~199
  string public constant PE_POOL_ALREADY_EXISTS = '100';
  string public constant PE_POOL_NOT_EXISTS = '101';
  string public constant PE_GROUP_ALREADY_EXISTS = '102';
  string public constant PE_GROUP_NOT_EXISTS = '103';
  string public constant PE_ASSET_ALREADY_EXISTS = '104';
  string public constant PE_ASSET_NOT_EXISTS = '105';
}
