// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {DataTypes} from '../types/DataTypes.sol';

library StorageSlot {
  bytes32 constant STORAGE_POSITION_POOL = bytes32(uint256(keccak256('benddao.proxy.pool.storage')) - 1);
  // keccak256(abi.encode(uint256(keccak256("benddao.storage.lidoPool.pool")) - 1)) & ~bytes32(uint256(0xff));
  bytes32 private constant STORAGE_POOL = 0xd8245ea713aac670829ae8e4b4eac346fd7fa97e5dae84d989268d370b026200;

  function getPoolStorage() internal pure returns (DataTypes.PoolStorage storage rs) {
    bytes32 position = STORAGE_POSITION_POOL;
    assembly {
      rs.slot := position
    }
  }

  function getStakePoolStorage() internal pure returns (DataTypes.StakePoolStorage storage $) {
    assembly {
      $.slot := STORAGE_POOL
    }
  }
}
