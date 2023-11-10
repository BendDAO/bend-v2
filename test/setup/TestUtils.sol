// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

contract TestUtils is Test {
  function to6Decimals(uint256 value) internal pure returns (uint256) {
    return value / 1e12;
  }

  function to8Decimals(uint256 value) internal pure returns (uint256) {
    return value / 1e10;
  }

  function testEquality(uint256 _firstValue, uint256 _secondValue) internal {
    assertApproxEqAbs(_firstValue, _secondValue, 20);
  }

  function testEquality(uint256 _firstValue, uint256 _secondValue, string memory err) internal {
    assertApproxEqAbs(_firstValue, _secondValue, 20, err);
  }

  function bytes32ToAddress(bytes32 _bytes) internal pure returns (address) {
    return address(uint160(uint256(_bytes)));
  }
}
