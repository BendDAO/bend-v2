// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

abstract contract Storage {
  // Dispatcher and upgrades

  uint internal reentrancyLock;

  mapping(uint => address) moduleLookup; // moduleId => module implementation
  mapping(uint => address) proxyLookup; // moduleId => proxy address (only for single-proxy modules)

  struct TrustedSenderInfo {
    uint32 moduleId; // 0 = un-trusted
    address moduleImpl; // only non-zero for external single-proxy modules
  }

  mapping(address => TrustedSenderInfo) trustedSenders; // sender address => moduleId (0 = un-trusted)
}
