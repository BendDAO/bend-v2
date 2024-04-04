// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Ownable2StepUpgradeable} from '@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol';

import {IACLManager} from 'src/interfaces/IACLManager.sol';
import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';

/**
 * @title AddressProvider
 * @notice Main registry of addresses part of or connected to the protocol, including permissioned roles
 */
contract AddressProvider is Ownable2StepUpgradeable, IAddressProvider {
  // Map of registered addresses (identifier => registeredAddress)
  mapping(bytes32 => address) private _addresses;

  // Main identifiers
  bytes32 private constant WRAPPED_NATIVE_TOKEN = 'WRAPPED_NATIVE_TOKEN';
  bytes32 private constant TREASURY = 'TREASURY';
  bytes32 private constant ACL_ADMIN = 'ACL_ADMIN';
  bytes32 private constant ACL_MANAGER = 'ACL_MANAGER';
  bytes32 private constant PRICE_ORACLE = 'PRICE_ORACLE';
  bytes32 private constant POOL_MANAGER = 'POOL_MANAGER';
  bytes32 private constant POOL_CONFIGURATOR = 'POOL_CONFIGURATOR';

  constructor() {
    _disableInitializers();
  }

  function initialize() public initializer {
    __Ownable2Step_init();
  }

  function getAddress(bytes32 id) public view override returns (address) {
    return _addresses[id];
  }

  function setAddress(bytes32 id, address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(id, newAddress);
    emit AddressSet(id, oldAddress, newAddress);
  }

  function getWrappedNativeToken() public view override returns (address) {
    return getAddress(WRAPPED_NATIVE_TOKEN);
  }

  function setWrappedNativeToken(address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(WRAPPED_NATIVE_TOKEN, newAddress);
    emit WrappedNativeTokenUpdated(oldAddress, newAddress);
  }

  function getTreasury() public view override returns (address) {
    return getAddress(TREASURY);
  }

  function setTreasury(address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(TREASURY, newAddress);
    emit TreasuryUpdated(oldAddress, newAddress);
  }

  function getACLAdmin() public view override returns (address) {
    return getAddress(ACL_ADMIN);
  }

  function setACLAdmin(address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(ACL_ADMIN, newAddress);
    emit ACLAdminUpdated(oldAddress, newAddress);
  }

  function getACLManager() public view override returns (address) {
    return getAddress(ACL_MANAGER);
  }

  function setACLManager(address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(ACL_MANAGER, newAddress);
    emit ACLManagerUpdated(oldAddress, newAddress);
  }

  function getPriceOracle() public view override returns (address) {
    return getAddress(PRICE_ORACLE);
  }

  function setPriceOracle(address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(PRICE_ORACLE, newAddress);
    emit PriceOracleUpdated(oldAddress, newAddress);
  }

  function getPoolManager() public view override returns (address) {
    return getAddress(POOL_MANAGER);
  }

  function setPoolManager(address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(POOL_MANAGER, newAddress);
    emit PoolManagerUpdated(oldAddress, newAddress);
  }

  function getPoolConfigurator() public view override returns (address) {
    return getAddress(POOL_CONFIGURATOR);
  }

  function setPoolConfigurator(address newAddress) public override onlyOwner {
    address oldAddress = _setAddress(POOL_CONFIGURATOR, newAddress);
    emit PoolConfiguratorUpdated(oldAddress, newAddress);
  }

  // internal methods

  function _setAddress(bytes32 id, address newAddress) internal returns (address) {
    address oldAddress = _addresses[id];
    _addresses[id] = newAddress;
    return oldAddress;
  }
}