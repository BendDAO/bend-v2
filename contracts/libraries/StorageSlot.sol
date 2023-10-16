// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import './DataTypes.sol';

library Storage {
  bytes32 constant STORAGE_POSITION_POOL_LENDING =
    bytes32(uint256(keccak256('benddao.proxy.pool.lending.storage')) - 1);
  bytes32 constant STORAGE_POSITION_POOL_YIELD = bytes32(uint256(keccak256('benddao.proxy.pool.yield.storage')) - 1);
  bytes32 constant STORAGE_POSITION_P2P_LENDING = bytes32(uint256(keccak256('benddao.proxy.p2p.lending.storage')) - 1);

  function getPoolLendingStorage() internal pure returns (DataTypes.PoolLendingStorage storage ps) {
    bytes32 position = STORAGE_POSITION_POOL_LENDING;
    assembly {
      ps.slot := position
    }
  }

  function getPoolYieldStorage() internal pure returns (DataTypes.PoolYieldStorage storage ps) {
    bytes32 position = STORAGE_POSITION_POOL_YIELD;
    assembly {
      ps.slot := position
    }
  }

  function getP2PLendingStorage() internal pure returns (DataTypes.P2PLendingStorage storage ps) {
    bytes32 position = STORAGE_POSITION_P2P_LENDING;
    assembly {
      ps.slot := position
    }
  }
}
