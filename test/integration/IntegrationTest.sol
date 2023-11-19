// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import '../setup/TestSetup.sol';

contract IntegrationTest is TestSetup {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }
}
