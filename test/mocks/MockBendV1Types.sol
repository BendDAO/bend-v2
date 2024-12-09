// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library MockBendV1Types {
  struct ReserveData {
    address underlyingAsset;
    address bTokenAddress;
    address debtTokenAddress;
  }
}
