// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IWUSDStaking {
  /** Datatypes */
  enum StakingStatus {
    ACTIVE,
    CLAIMABLE,
    CLAIMED
  }
  enum ClaimType {
    UNCLAIMED,
    PREMATURED,
    MATURED
  }

  enum StakingPoolStatus {
    INACTIVE,
    ACTIVE
  }

  struct StakingPool {
    uint48 stakingPeriod;
    uint256 apy;
    uint256 minStakingAmount;
    StakingPoolStatus status;
  }

  struct StakingPoolDetail {
    uint256 stakingPoolId;
    StakingPool stakingPool;
  }

  struct StakingPlan {
    uint256 stakingPoolId;
    uint256 stakedAmount;
    uint256 apy;
    uint48 startTime;
    uint48 endTime;
    uint48 claimableTimestamp;
    uint256 yield;
    StakingStatus stakingStatus;
    ClaimType claimType;
  }

  function stake(uint256 stakingPoolId, uint256 stakingAmount) external returns (uint256 stakingPlanId);

  function terminate(uint256 stakingPlanId) external;

  function claim(uint256[] calldata stakingPlanIds) external;

  function getUserStakingPlan(address staker, uint256 stakingPlanId) external view returns (StakingPlan memory);

  function getBasicAPY() external view returns (uint256);
}
