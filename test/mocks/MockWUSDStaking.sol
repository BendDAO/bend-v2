// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IWUSDStaking} from 'src/yield/wusd/IWUSDStaking.sol';

contract MockWUSDStaking is IWUSDStaking, Ownable2Step {
  using SafeERC20 for IERC20;

  /** constant */
  uint48 constant FLEXIBLE_STAKING = type(uint48).max;
  uint48 public constant SECONDS_OF_YEAR = 31536000;
  uint256 constant DENOMINATOR = 1e6;

  address public WUSD;
  address private _poolAddress;
  uint256 private _numberOfStakingPools;
  uint256 private _basicAPY;
  uint48 private _cooldownDuration;
  mapping(uint256 => StakingPool) private _stakingPools;
  mapping(address => mapping(uint256 => StakingPlan)) private _userStakingPlans;
  mapping(address => uint256) private _totalStakingPlansByAddress;

  constructor(address wusd) {
    WUSD = wusd;

    _poolAddress = address(this);
    _basicAPY = 50000;
    _cooldownDuration = 172800;
  }

  function stake(uint256 stakingPoolId, uint256 stakingAmount) external returns (uint256) {
    StakingPool memory stakingPool = _stakingPools[stakingPoolId];

    IERC20(WUSD).safeTransferFrom(_msgSender(), _poolAddress, stakingAmount);

    uint48 endTime = uint48(block.timestamp) + stakingPool.stakingPeriod;
    uint256 stakingPlanId = ++_totalStakingPlansByAddress[_msgSender()];

    _userStakingPlans[_msgSender()][stakingPlanId] = StakingPlan({
      stakingPoolId: stakingPoolId,
      stakedAmount: stakingAmount,
      apy: stakingPool.apy,
      startTime: uint48(block.timestamp),
      endTime: endTime,
      claimableTimestamp: 0,
      yield: 0,
      stakingStatus: StakingStatus.ACTIVE,
      claimType: ClaimType.UNCLAIMED
    });

    return stakingPlanId;
  }

  function terminate(uint256 stakingPlanId) external {
    StakingPlan storage stakingPlan = _userStakingPlans[_msgSender()][stakingPlanId];

    if (stakingPlan.stakingStatus != StakingStatus.ACTIVE) {
      revert('InvalidStakingPlan');
    }
    if (uint256(stakingPlan.endTime) < block.timestamp) {
      revert('MaturedStakingPlan');
    }

    stakingPlan.claimType = ClaimType.PREMATURED;
    stakingPlan.yield = _calculateYield(
      stakingPlan.stakedAmount,
      _basicAPY,
      uint48(block.timestamp) - stakingPlan.startTime
    );
    stakingPlan.claimableTimestamp = uint48(block.timestamp) + _cooldownDuration;
    stakingPlan.stakingStatus = StakingStatus.CLAIMABLE;
  }

  function claim(uint256[] calldata stakingPlanIds) external {
    uint256 totalReceived = 0;

    for (uint256 i = 0; i < stakingPlanIds.length; i++) {
      StakingPlan storage stakingPlan = _claim(stakingPlanIds[i]);
      totalReceived += stakingPlan.stakedAmount + stakingPlan.yield;
    }

    if (_poolAddress == address(this)) {
      IERC20(WUSD).safeTransfer(_msgSender(), totalReceived);
    } else {
      IERC20(WUSD).safeTransferFrom(_poolAddress, _msgSender(), totalReceived);
    }
  }

  function _claim(uint256 stakingPlanId) internal returns (StakingPlan storage) {
    if (stakingPlanId == 0) {
      revert('InvalidId');
    }

    StakingPlan storage stakingPlan = _userStakingPlans[_msgSender()][stakingPlanId];

    if (stakingPlan.apy == 0) {
      revert('InvalidStakingPlan');
    }

    if (stakingPlan.stakingStatus == StakingStatus.CLAIMED) {
      revert('StakeIsClaimed');
    }

    uint48 currentTime = uint48(block.timestamp);

    if (stakingPlan.stakingStatus == StakingStatus.CLAIMABLE) {
      if (currentTime < stakingPlan.claimableTimestamp) {
        revert('ClaimableTimestampNotReached');
      }
    } else if (stakingPlan.endTime > currentTime) {
      revert('UnclaimableStakingPlan');
    } else {
      stakingPlan.claimType = ClaimType.MATURED;
      stakingPlan.yield = _calculateYield(
        stakingPlan.stakedAmount,
        stakingPlan.apy,
        stakingPlan.endTime - stakingPlan.startTime
      );
    }
    stakingPlan.stakingStatus = StakingStatus.CLAIMED;

    return stakingPlan;
  }

  function _calculateYield(uint256 stakedAmount, uint256 apy, uint48 stakingDuration) internal pure returns (uint256) {
    return (stakedAmount * apy * stakingDuration) / SECONDS_OF_YEAR / DENOMINATOR;
  }

  function getGeneralStaking() external view returns (StakingPoolDetail[] memory stakingPoolsDetail) {
    stakingPoolsDetail = new StakingPoolDetail[](_numberOfStakingPools);

    // stakingPoolId starts from 1
    uint256 activePoolCount = 0;
    for (uint256 i = 1; i <= _numberOfStakingPools; i++) {
      StakingPool memory stakingPool = _stakingPools[i];

      if (stakingPool.status == StakingPoolStatus.ACTIVE) {
        stakingPoolsDetail[activePoolCount].stakingPoolId = i;
        stakingPoolsDetail[activePoolCount].stakingPool = stakingPool;
        activePoolCount++;
      }
    }

    assembly {
      mstore(stakingPoolsDetail, activePoolCount)
    }

    return stakingPoolsDetail;
  }

  function getStakingPoolDetails(uint256 stakingPoolId) external view returns (StakingPool memory) {
    return _stakingPools[stakingPoolId];
  }

  function getUserStakingPlans(address staker) external view returns (StakingPlanDetail[] memory stakingRecords) {
    uint256 totalPlansByStaker = _totalStakingPlansByAddress[staker];
    stakingRecords = new StakingPlanDetail[](totalPlansByStaker);

    for (uint256 i = 0; i < totalPlansByStaker; i++) {
      stakingRecords[i].stakingPlanId = i + 1;
      stakingRecords[i].stakingPlan = _userStakingPlans[staker][i + 1];
    }

    return stakingRecords;
  }

  function getUserStakingPlan(address staker, uint256 stakingPlanId) external view returns (StakingPlan memory) {
    return _userStakingPlans[staker][stakingPlanId];
  }

  function setPoolAddress(address newPoolAddress) external onlyOwner {
    _poolAddress = newPoolAddress;
  }

  function getPoolAddress() external view returns (address) {
    return _poolAddress;
  }

  function createStakingPool(uint48 stakingPeriod, uint256 apy, uint256 minStakingAmount) external onlyOwner {
    uint256 stakingPoolId = ++_numberOfStakingPools;
    _stakingPools[stakingPoolId] = StakingPool({
      stakingPeriod: stakingPeriod,
      apy: apy,
      minStakingAmount: minStakingAmount,
      status: StakingPoolStatus.ACTIVE
    });
  }

  function updateStakingPoolAPY(uint256 stakingPoolId, uint256 newAPY) external onlyOwner {
    _stakingPools[stakingPoolId].apy = newAPY;
  }

  function updateStakingPoolStatus(uint256 stakingPoolId, StakingPoolStatus stakingPoolStatus) external onlyOwner {
    _stakingPools[stakingPoolId].status = stakingPoolStatus;
  }

  function setBasicAPY(uint256 newBasicAPY) external onlyOwner {
    _basicAPY = newBasicAPY;
  }

  function getBasicAPY() external view returns (uint256) {
    return _basicAPY;
  }

  function setCooldownDuration(uint48 newCooldownDuration) external onlyOwner {
    _cooldownDuration = newCooldownDuration;
  }

  function getCooldownDuration() external view returns (uint256) {
    return _cooldownDuration;
  }
}
