// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeCastUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import {IInterestRateModel} from '../../interfaces/IInterestRateModel.sol';

import {MathUtils} from '..//math/MathUtils.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {PercentageMath} from '../math/PercentageMath.sol';

import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {InputTypes} from '../types/InputTypes.sol';

/**
 * @title InterestLogic library
 * @notice Implements the logic to update the interest state
 */
library InterestLogic {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using SafeCastUpgradeable for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  /**
   * @notice Returns the ongoing normalized supply income for the asset.
   * @dev A value of 1e27 means there is no income. As time passes, the income is accrued
   * @dev A value of 2*1e27 means for each unit of asset one unit of income has been accrued
   */
  function getNormalizedSupplyIncome(DataTypes.AssetData storage assetData) internal view returns (uint256) {
    uint40 timestamp = assetData.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == block.timestamp) {
      //if the index was updated in the same block, no need to perform any calculation
      return assetData.supplyIndex;
    } else {
      return MathUtils.calculateLinearInterest(assetData.supplyRate, timestamp).rayMul(assetData.supplyIndex);
    }
  }

  /**
   * @notice Returns the ongoing normalized borrow debt for the reserve.
   * @dev A value of 1e27 means there is no debt. As time passes, the debt is accrued
   * @dev A value of 2*1e27 means that for each unit of debt, one unit worth of interest has been accumulated
   */
  function getNormalizedBorrowDebt(DataTypes.GroupData storage groupData) internal view returns (uint256) {
    uint40 timestamp = groupData.lastUpdateTimestamp;

    //solium-disable-next-line
    if (timestamp == block.timestamp) {
      //if the index was updated in the same block, no need to perform any calculation
      return groupData.borrowIndex;
    } else {
      return MathUtils.calculateCompoundedInterest(groupData.borrowRate, timestamp).rayMul(groupData.borrowIndex);
    }
  }

  function updateInterestSupplyIndex(DataTypes.AssetData storage assetData) internal {
    // If time didn't pass since last stored timestamp, skip state update

    //solium-disable-next-line
    if (assetData.lastUpdateTimestamp != uint40(block.timestamp)) {
      _updateSupplyIndex(assetData);
      assetData.lastUpdateTimestamp = uint40(block.timestamp);
    }
  }

  function updateInterestBorrowIndex(
    DataTypes.AssetData storage assetData,
    DataTypes.GroupData storage groupData
  ) internal {
    // If time didn't pass since last stored timestamp, skip state update

    //solium-disable-next-line
    if (groupData.lastUpdateTimestamp != uint40(block.timestamp)) {
      uint256 prevGroupBorrowIndex = groupData.borrowIndex;

      _updateBorrowIndex(groupData);

      _accrueToTreasury(assetData, groupData, prevGroupBorrowIndex);

      //solium-disable-next-line
      groupData.lastUpdateTimestamp = uint40(block.timestamp);
    }
  }

  /**
   * @notice Updates the cumulative supply index and the borrow index.
   */
  function updateInterestIndexs(DataTypes.AssetData storage assetData, DataTypes.GroupData storage groupData) internal {
    // If time didn't pass since last stored timestamp, skip state update

    //solium-disable-next-line
    if (assetData.lastUpdateTimestamp != uint40(block.timestamp)) {
      _updateSupplyIndex(assetData);
      assetData.lastUpdateTimestamp = uint40(block.timestamp);
    }

    //solium-disable-next-line
    if (groupData.lastUpdateTimestamp != uint40(block.timestamp)) {
      uint256 prevGroupBorrowIndex = groupData.borrowIndex;

      _updateBorrowIndex(groupData);

      _accrueToTreasury(assetData, groupData, prevGroupBorrowIndex);

      //solium-disable-next-line
      groupData.lastUpdateTimestamp = uint40(block.timestamp);
    }
  }

  /**
   * @notice Accumulates a predefined amount of asset to the asset as a fixed, instantaneous income. Used for example
   * to accumulate the flashloan fee to the asset, and spread it between all the suppliers.
   */
  function cumulateToSupplyIndex(
    DataTypes.AssetData storage assetData,
    uint256 totalSupply,
    uint256 amount
  ) internal returns (uint256) {
    //next supply index is calculated this way: `((amount / totalSupply) + 1) * supplyIndex`
    //division `amount / totalSupply` done in ray for precision
    uint256 result = (amount.wadToRay().rayDiv(totalSupply.wadToRay()) + WadRayMath.RAY).rayMul(assetData.supplyIndex);
    assetData.supplyIndex = result.toUint128();
    return result;
  }

  /**
   * @notice Initializes a asset.
   */
  function initAssetData(DataTypes.AssetData storage assetData) internal {
    require(assetData.supplyIndex == 0, Errors.ASSET_ALREADY_EXISTS);
    assetData.supplyIndex = uint128(WadRayMath.RAY);
  }

  function initGroupData(DataTypes.GroupData storage groupData) internal {
    require(groupData.borrowIndex == 0, Errors.GROUP_ALREADY_EXISTS);
    groupData.borrowIndex = uint128(WadRayMath.RAY);
  }

  struct UpdateInterestRatesLocalVars {
    uint256[] assetGroupIds;
    uint8 loopGroupId;
    uint256 loopGroupScaledDebt;
    uint256 loopGroupDebt;
    uint256[] allGroupDebtList;
    uint256 totalAssetScaledDebt;
    uint256 totalAssetDebt;
    uint256 availableLiquidity;
    uint256 availableLiquidityPlusDebt;
    uint256 assetBorrowUsageRatio;
    uint256 groupBorrowUsageRatio;
    uint256 nextGroupBorrowRate;
    uint256 avgAssetBorrowRate;
    uint256 nextAssetSupplyRate;
  }

  /**
   * @notice Updates the asset current borrow rate and current supply rate.
   */
  function updateInterestRates(
    address assetAddress,
    DataTypes.AssetData storage assetData,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    UpdateInterestRatesLocalVars memory vars;

    vars.assetGroupIds = assetData.groupList.values();

    // calculate the total asset debt
    vars.allGroupDebtList = new uint256[](vars.assetGroupIds.length);
    for (uint256 i = 0; i < vars.assetGroupIds.length; i++) {
      vars.loopGroupId = uint8(vars.assetGroupIds[i]);
      DataTypes.GroupData storage loopGroupData = assetData.groupLookup[vars.loopGroupId];
      vars.loopGroupScaledDebt = loopGroupData.totalCrossBorrowed + loopGroupData.totalIsolateBorrowed;
      vars.loopGroupDebt = vars.loopGroupScaledDebt.rayMul(loopGroupData.borrowIndex);
      vars.allGroupDebtList[i] = vars.loopGroupDebt;

      vars.totalAssetDebt += vars.loopGroupDebt;
    }

    // calculate the total asset supply
    vars.availableLiquidity =
      IERC20Upgradeable(assetAddress).balanceOf(address(this)) +
      liquidityAdded -
      liquidityTaken;
    vars.availableLiquidityPlusDebt = vars.availableLiquidity + vars.totalAssetDebt;
    vars.assetBorrowUsageRatio = vars.totalAssetDebt.rayDiv(vars.availableLiquidityPlusDebt);

    // calculate the group borrow rate
    for (uint256 i = 0; i < vars.assetGroupIds.length; i++) {
      vars.loopGroupId = uint8(vars.assetGroupIds[i]);
      DataTypes.GroupData storage loopGroupData = assetData.groupLookup[vars.loopGroupId];
      (vars.nextGroupBorrowRate) = IInterestRateModel(loopGroupData.interestRateModelAddress).calculateGroupBorrowRate(
        InputTypes.CalculateGroupBorrowRateParams({
          assetAddress: assetAddress,
          borrowUsageRatio: vars.assetBorrowUsageRatio
        })
      );

      loopGroupData.borrowRate = vars.nextGroupBorrowRate.toUint128();

      emit Events.AssetInterestBorrowDataUpdated(
        assetAddress,
        vars.loopGroupId,
        vars.nextGroupBorrowRate,
        loopGroupData.borrowIndex
      );
    }

    // calculate the asset supply rate
    vars.avgAssetBorrowRate = 0;
    for (uint256 i = 0; i < vars.assetGroupIds.length; i++) {
      vars.loopGroupId = uint8(vars.assetGroupIds[i]);
      DataTypes.GroupData storage loopGroupData = assetData.groupLookup[vars.loopGroupId];

      if ((vars.totalAssetDebt != 0) && (vars.allGroupDebtList[i] != 0)) {
        vars.groupBorrowUsageRatio = vars.allGroupDebtList[i].rayDiv(vars.totalAssetDebt);
        vars.avgAssetBorrowRate += uint256(loopGroupData.borrowRate).rayMul(vars.groupBorrowUsageRatio);
      }
    }

    vars.nextAssetSupplyRate = vars.avgAssetBorrowRate.rayMul(vars.assetBorrowUsageRatio);
    vars.nextAssetSupplyRate = vars.nextAssetSupplyRate.percentMul(
      PercentageMath.PERCENTAGE_FACTOR - assetData.feeFactor
    );
    assetData.supplyRate = vars.nextAssetSupplyRate.toUint128();

    emit Events.AssetInterestSupplyDataUpdated(assetAddress, vars.nextAssetSupplyRate, assetData.supplyIndex);
  }

  struct AccrueToTreasuryLocalVars {
    uint256 totalScaledVariableDebt;
    uint256 prevTotalVariableDebt;
    uint256 currTotalVariableDebt;
    uint256 totalDebtAccrued;
    uint256 amountToMint;
  }

  /**
   * @notice Mints part of the repaid interest to the reserve treasury as a function of the reserve factor for the
   * specific asset.
   */
  function _accrueToTreasury(
    DataTypes.AssetData storage assetData,
    DataTypes.GroupData storage groupData,
    uint256 prevGroupBorrowIndex
  ) internal {
    AccrueToTreasuryLocalVars memory vars;

    if (assetData.feeFactor == 0) {
      return;
    }

    vars.totalScaledVariableDebt = groupData.totalCrossBorrowed + groupData.totalIsolateBorrowed;

    //calculate the total variable debt at moment of the last interaction
    vars.prevTotalVariableDebt = vars.totalScaledVariableDebt.rayMul(prevGroupBorrowIndex);

    //calculate the new total variable debt after accumulation of the interest on the index
    vars.currTotalVariableDebt = vars.totalScaledVariableDebt.rayMul(groupData.borrowIndex);

    //debt accrued is the sum of the current debt minus the sum of the debt at the last update
    vars.totalDebtAccrued = vars.currTotalVariableDebt - vars.prevTotalVariableDebt;

    vars.amountToMint = vars.totalDebtAccrued.percentMul(assetData.feeFactor);

    if (vars.amountToMint != 0) {
      assetData.accruedFee += vars.amountToMint.rayDiv(assetData.supplyIndex).toUint128();
    }
  }

  /**
   * @notice Updates the asset supply index and the timestamp of the update.
   */
  function _updateSupplyIndex(DataTypes.AssetData storage assetData) internal {
    // Only cumulating on the supply side if there is any income being produced
    // The case of Reserve Factor 100% is not a problem (currentLiquidityRate == 0),
    // as liquidity index should not be updated
    if (assetData.supplyRate != 0) {
      uint256 cumulatedSupplyInterest = MathUtils.calculateLinearInterest(
        assetData.supplyRate,
        assetData.lastUpdateTimestamp
      );
      uint256 nextSupplyIndex = cumulatedSupplyInterest.rayMul(assetData.supplyIndex);
      assetData.supplyIndex = nextSupplyIndex.toUint128();
    }
  }

  /**
   * @notice Updates the group borrow index and the timestamp of the update.
   */
  function _updateBorrowIndex(DataTypes.GroupData storage groupData) internal {
    // borrow index only gets updated if there is any variable debt.
    // groupData.borrowRate != 0 is not a correct validation,
    // because a positive base variable rate can be stored on
    // groupData.borrowRate, but the index should not increase
    if ((groupData.totalCrossBorrowed != 0) || (groupData.totalIsolateBorrowed != 0)) {
      uint256 cumulatedBorrowInterest = MathUtils.calculateCompoundedInterest(
        groupData.borrowRate,
        groupData.lastUpdateTimestamp
      );
      uint256 nextBorrowIndex = cumulatedBorrowInterest.rayMul(groupData.borrowIndex);
      groupData.borrowIndex = nextBorrowIndex.toUint128();
    }
  }
}
