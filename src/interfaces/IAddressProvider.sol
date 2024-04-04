// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

interface IAddressProvider {
  event AddressSet(bytes32 indexed id, address indexed oldAddress, address indexed newAddress);

  event WrappedNativeTokenUpdated(address indexed oldAddress, address indexed newAddress);

  event TreasuryUpdated(address indexed oldAddress, address indexed newAddress);

  event ACLAdminUpdated(address indexed oldAddress, address indexed newAddress);

  event ACLManagerUpdated(address indexed oldAddress, address indexed newAddress);

  event PriceOracleUpdated(address indexed oldAddress, address indexed newAddress);

  event PoolManagerUpdated(address indexed oldAddress, address indexed newAddress);

  event PoolConfiguratorUpdated(address indexed oldAddress, address indexed newAddress);

  function getAddress(bytes32 id) external view returns (address);

  function setAddress(bytes32 id, address newAddress) external;

  function getWrappedNativeToken() external view returns (address);

  function setWrappedNativeToken(address newAddress) external;

  function getTreasury() external view returns (address);

  function setTreasury(address newAddress) external;

  function getACLAdmin() external view returns (address);

  function setACLAdmin(address newAddress) external;

  function getACLManager() external view returns (address);

  function setACLManager(address newAddress) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address newAddress) external;

  function getPoolManager() external view returns (address);

  function setPoolManager(address newAddress) external;

  function getPoolConfigurator() external view returns (address);

  function setPoolConfigurator(address newAddress) external;
}