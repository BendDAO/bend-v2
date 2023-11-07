// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {InputTypes} from '../libraries/types/InputTypes.sol';

/**
 * @title IInterestRateModel
 * @notice Defines the basic interface for the Interest Rate Model
 */
interface IInterestRateModel {
  /**
   * @notice Calculates the interest rate depending on the group's state and configurations
   * @param params The parameters needed to calculate interest rates
   * @return borrowRate The group borrow rate expressed in rays
   */
  function calculateGroupBorrowRate(
    InputTypes.CalculateGroupBorrowRateParams memory params
  ) external view returns (uint256);
}
