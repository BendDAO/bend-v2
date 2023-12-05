// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

import '../setup/TestWithAction.sol';

contract TestWithIntegration is TestWithAction {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }
}
