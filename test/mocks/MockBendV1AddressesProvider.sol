// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ILendPoolAddressesProviderV1} from 'src/migrations/IBendV1Interface.sol';

contract MockBendV1AddressesProvider is ILendPoolAddressesProviderV1 {
  address public lendPool;
  address public lendPoolLoan;
  address public dataProvider;

  function getLendPool() public view returns (address) {
    return lendPool;
  }

  function getLendPoolLoan() public view returns (address) {
    return lendPoolLoan;
  }

  function getBendDataProvider() public view returns (address) {
    return dataProvider;
  }

  function setLendPool(address lendPool_) public {
    lendPool = lendPool_;
  }

  function setLendPoolLoan(address lendPoolLoan_) public {
    lendPoolLoan = lendPoolLoan_;
  }

  function setBendDataProvider(address dataProvider_) public {
    dataProvider = dataProvider_;
  }
}
