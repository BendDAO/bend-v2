// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {stdJson} from '@forge-std/StdJson.sol';

struct Config {
  string json;
}

library ConfigLib {
  using stdJson for string;

  string internal constant CHAIN_ID_PATH = '$.chainId';
  string internal constant RPC_ALIAS_PATH = '$.rpcAlias';
  string internal constant FORK_BLOCK_NUMBER_PATH = '$.forkBlockNumber';
  string internal constant WRAPPED_NATIVE_PATH = '$.wrappedNative';
  string internal constant ACL_MANAGER_PATH = '$.aclManager';
  string internal constant PRICE_ORACLE_PATH = '$.priceOracle';

  function getAddress(Config storage config, string memory key) internal view returns (address) {
    return config.json.readAddress(string.concat('$.', key));
  }

  function getAddressArray(
    Config storage config,
    string[] memory keys
  ) internal view returns (address[] memory addresses) {
    addresses = new address[](keys.length);

    for (uint256 i; i < keys.length; ++i) {
      addresses[i] = getAddress(config, keys[i]);
    }
  }

  function getChainId(Config storage config) internal view returns (uint256) {
    return config.json.readUint(CHAIN_ID_PATH);
  }

  function getRpcAlias(Config storage config) internal view returns (string memory) {
    return config.json.readString(RPC_ALIAS_PATH);
  }

  function getForkBlockNumber(Config storage config) internal view returns (uint256) {
    return config.json.readUint(FORK_BLOCK_NUMBER_PATH);
  }

  function getWrappedNative(Config storage config) internal view returns (address) {
    return getAddress(config, config.json.readString(WRAPPED_NATIVE_PATH));
  }

  function getACLManager(Config storage config) internal view returns (address) {
    return config.json.readAddress(ACL_MANAGER_PATH);
  }

  function getPriceOracle(Config storage config) internal view returns (address) {
    return config.json.readAddress(PRICE_ORACLE_PATH);
  }
}
