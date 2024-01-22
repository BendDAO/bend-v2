// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import '../types/DataTypes.sol';

library StorageSlot {
  bytes32 constant STORAGE_POSITION_POOL = bytes32(uint256(keccak256('benddao.proxy.pool.storage')) - 1);

  function getPoolStorage() internal pure returns (DataTypes.PoolStorage storage rs) {
    bytes32 position = STORAGE_POSITION_POOL;
    assembly {
      rs.slot := position
    }
  }
}
