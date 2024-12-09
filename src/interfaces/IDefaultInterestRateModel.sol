// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IInterestRateModel} from './IInterestRateModel.sol';

interface IDefaultInterestRateModel is IInterestRateModel {
  /**
   * @notice Returns the usage ratio at which the pool aims to obtain most competitive borrow rates.
   * @return The optimal usage ratio, expressed in ray.
   */
  function getOptimalUtilizationRate(uint32 pool, address asset, uint256 group) external view returns (uint256);

  /**
   * @notice Returns the base variable borrow rate
   * @return The base variable borrow rate, expressed in ray
   */
  function getBaseVariableBorrowRate(uint32 pool, address asset, uint256 group) external view returns (uint256);

  /**
   * @notice Returns the rate slope below optimal usage ratio
   * @dev It's the variable rate when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO
   * @return The variable rate slope, expressed in ray
   */
  function getVariableRateSlope1(uint32 pool, address asset, uint256 group) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope above optimal usage ratio
   * @dev It's the variable rate when usage ratio > OPTIMAL_USAGE_RATIO
   * @return The variable rate slope, expressed in ray
   */
  function getVariableRateSlope2(uint32 pool, address asset, uint256 group) external view returns (uint256);

  /**
   * @notice Returns the maximum variable borrow rate
   * @return The maximum variable borrow rate, expressed in ray
   */
  function getMaxVariableBorrowRate(uint32 pool, address asset, uint256 group) external view returns (uint256);
}
