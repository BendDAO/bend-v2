// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
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
    (, , , , uint256 healthFactor, bool hasZeroLtvCollateral) = GenericLogic.calculateUserAccountData(
      poolData,
      userAccount,
      oracle
    );

    require(
      healthFactor >= Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.PE_HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
    );

    return (healthFactor, hasZeroLtvCollateral);
  }
}
