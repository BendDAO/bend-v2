// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ILendPoolAddressesProviderV1} from 'src/migrations/IBendV1Interface.sol';
import {IBendProtocolDataProviderV1} from 'src/migrations/IBendV1Interface.sol';

import './MockBendV1Types.sol';
import './MockBendV1LendPool.sol';

contract MockBendV1ProtocolDataProvider is IBendProtocolDataProviderV1 {
  ILendPoolAddressesProviderV1 public addressProvider;

  constructor(address provider_) {
    addressProvider = ILendPoolAddressesProviderV1(provider_);
  }

  function getReserveTokenData(address asset) public view returns (ReserveTokenData memory) {
    MockBendV1LendPool pool = MockBendV1LendPool(addressProvider.getLendPool());

    MockBendV1Types.ReserveData memory reserveData = pool.getReserveData(asset);

    return
      ReserveTokenData({
        tokenSymbol: 'Asset',
        tokenAddress: asset,
        bTokenSymbol: 'bAsset',
        bTokenAddress: reserveData.bTokenAddress,
        debtTokenSymbol: 'debtAsset',
        debtTokenAddress: reserveData.debtTokenAddress
      });
  }
}
