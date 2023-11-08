// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {ResultTypes} from '../types/ResultTypes.sol';

import {StorageSlot} from './StorageSlot.sol';
import {GenericLogic} from './GenericLogic.sol';

library RiskManagerLogic {
  /**
   * @notice Checks the health factor of a user.
   */
  function checkHealthFactor(
    DataTypes.PoolData storage poolData,
    address userAccount,
    address oracle
  ) internal view returns (uint256, bool) {
    ResultTypes.UserAccountResult memory userAccountResult = GenericLogic.calculateUserAccountData(
      poolData,
      userAccount,
      address(0),
      oracle
    );

    require(
      userAccountResult.healthFactor >= Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
    );

    return (userAccountResult.healthFactor, userAccountResult.hasZeroLtvCollateral);
  }
}
