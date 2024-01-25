// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import '../types/ResultTypes.sol';

import './StorageSlot.sol';
import './VaultLogic.sol';
import './GenericLogic.sol';
import './InterestLogic.sol';

library QueryLogic {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function getPoolMaxAssetNumber() public pure returns (uint256) {
    return Constants.MAX_NUMBER_OF_ASSET;
  }

  function getPoolMaxGroupNumber() public pure returns (uint256) {
    return Constants.MAX_NUMBER_OF_GROUP;
  }

  function getPoolGroupList(uint32 poolId) public view returns (uint256[] memory) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    return poolData.groupList.values();
  }

  function getPoolAssetList(uint32 poolId) public view returns (address[] memory) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    return poolData.assetList.values();
  }

  function getAssetGroupList(uint32 poolId, address asset) public view returns (uint256[] memory) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return assetData.groupList.values();
  }

  function getAssetConfigFlag(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      bool isActive,
      bool isFrozen,
      bool isPaused,
      bool isBorrowingEnabled,
      bool isYieldEnabled,
      bool isYieldPaused
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (
      assetData.isActive,
      assetData.isFrozen,
      assetData.isPaused,
      assetData.isBorrowingEnabled,
      assetData.isYieldEnabled,
      assetData.isYieldPaused
    );
  }

  function getAssetConfigCap(
    uint32 poolId,
    address asset
  ) public view returns (uint256 supplyCap, uint256 borrowCap, uint256 yieldCap) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (assetData.supplyCap, assetData.borrowCap, assetData.yieldCap);
  }

  function getAssetLendingConfig(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      uint8 classGroup,
      uint16 feeFactor,
      uint16 collateralFactor,
      uint16 liquidationThreshold,
      uint16 liquidationBonus
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (
      assetData.classGroup,
      assetData.feeFactor,
      assetData.collateralFactor,
      assetData.liquidationThreshold,
      assetData.liquidationBonus
    );
  }

  function getAssetAuctionConfig(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (uint16 redeemThreshold, uint16 bidFineFactor, uint16 minBidFineFactor, uint40 auctionDuration)
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (assetData.redeemThreshold, assetData.bidFineFactor, assetData.minBidFineFactor, assetData.auctionDuration);
  }

  function getAssetSupplyData(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      uint256 totalScaledCrossSupply,
      uint256 totalCrossSupply,
      uint256 totalScaledIsolateSupply,
      uint256 totalIsolateSupply,
      uint256 availableSupply,
      uint256 supplyRate,
      uint256 supplyIndex,
      uint256 lastUpdateTimestamp
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      totalScaledCrossSupply = VaultLogic.erc20GetTotalScaledCrossSupply(assetData);
      totalScaledIsolateSupply = VaultLogic.erc20GetTotalScaledIsolateSupply(assetData);

      uint256 index = InterestLogic.getNormalizedSupplyIncome(assetData);
      totalCrossSupply = VaultLogic.erc20GetTotalCrossSupply(assetData, index);
      totalIsolateSupply = VaultLogic.erc20GetTotalIsolateSupply(assetData, index);
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      totalScaledCrossSupply = totalCrossSupply = VaultLogic.erc721GetTotalCrossSupply(assetData);
      totalScaledIsolateSupply = totalIsolateSupply = VaultLogic.erc721GetTotalIsolateSupply(assetData);
    }

    availableSupply = assetData.availableLiquidity;
    supplyRate = assetData.supplyRate;
    supplyIndex = assetData.supplyIndex;
    lastUpdateTimestamp = assetData.lastUpdateTimestamp;
  }

  function getAssetGroupData(
    uint32 poolId,
    address asset,
    uint8 group
  )
    public
    view
    returns (
      uint256 totalScaledCrossBorrow,
      uint256 totalCrossBorrow,
      uint256 totalScaledIsolateBorrow,
      uint256 totalIsolateBorrow,
      uint256 borrowRate,
      uint256 borrowIndex,
      address rateModel
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[group];

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      totalScaledCrossBorrow = VaultLogic.erc20GetTotalScaledCrossBorrowInGroup(groupData);
      totalScaledIsolateBorrow = VaultLogic.erc20GetTotalScaledIsolateBorrowInGroup(groupData);

      uint256 index = InterestLogic.getNormalizedBorrowDebt(assetData, groupData);
      totalCrossBorrow = VaultLogic.erc20GetTotalCrossBorrowInGroup(groupData, index);
      totalIsolateBorrow = VaultLogic.erc20GetTotalIsolateBorrowInGroup(groupData, index);

      borrowRate = groupData.borrowRate;
      borrowIndex = groupData.borrowIndex;
      rateModel = groupData.rateModel;
    }
  }

  function getUserAccountData(
    address user,
    uint32 poolId
  )
    public
    view
    returns (
      uint256 totalCollateralInBase,
      uint256 totalBorrowInBase,
      uint256 availableBorrowInBase,
      uint256 currentCollateralFactor,
      uint256 currentLiquidationThreshold,
      uint256 healthFactor
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    ResultTypes.UserAccountResult memory result = GenericLogic.calculateUserAccountDataForHeathFactor(
      poolData,
      user,
      ps.priceOracle
    );

    totalCollateralInBase = result.totalCollateralInBaseCurrency;
    totalBorrowInBase = result.totalDebtInBaseCurrency;

    availableBorrowInBase = GenericLogic.calculateAvailableBorrows(
      totalCollateralInBase,
      totalBorrowInBase,
      result.avgLtv
    );

    currentCollateralFactor = result.avgLtv;
    currentLiquidationThreshold = result.avgLiquidationThreshold;
    healthFactor = result.healthFactor;
  }

  struct GetUserAssetDataLocalVars {
    uint256 aidx;
    uint256 gidx;
    uint256[] assetGroupIds;
    uint256 index;
  }

  function getUserAssetData(
    address user,
    uint32 poolId,
    address asset
  )
    public
    view
    returns (uint256 totalCrossSupply, uint256 totalIsolateSupply, uint256 totalCrossBorrow, uint256 totalIsolateBorrow)
  {
    GetUserAssetDataLocalVars memory vars;

    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    vars.assetGroupIds = assetData.groupList.values();

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      vars.index = InterestLogic.getNormalizedSupplyIncome(assetData);
      totalCrossSupply = VaultLogic.erc20GetUserCrossSupply(assetData, user, vars.index);

      for (vars.gidx = 0; vars.gidx < vars.assetGroupIds.length; vars.gidx++) {
        DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(vars.assetGroupIds[vars.gidx])];
        vars.index = InterestLogic.getNormalizedBorrowDebt(assetData, groupData);
        totalCrossBorrow += VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, user, vars.index);
        totalIsolateBorrow += VaultLogic.erc20GetUserIsolateBorrowInGroup(groupData, user, vars.index);
      }
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      totalCrossSupply = VaultLogic.erc721GetUserCrossSupply(assetData, user);
      totalIsolateSupply = VaultLogic.erc721GetUserIsolateSupply(assetData, user);
    }
  }

  function getUserAssetScaledData(
    address user,
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      uint256 totalScaledCrossSupply,
      uint256 totalScaledIsolateSupply,
      uint256 totalScaledCrossBorrow,
      uint256 totalScaledIsolateBorrow
    )
  {
    GetUserAssetDataLocalVars memory vars;

    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    vars.assetGroupIds = assetData.groupList.values();

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      totalScaledCrossSupply = VaultLogic.erc20GetUserScaledCrossSupply(assetData, user);

      for (vars.gidx = 0; vars.gidx < vars.assetGroupIds.length; vars.gidx++) {
        DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(vars.assetGroupIds[vars.gidx])];
        totalScaledCrossBorrow += VaultLogic.erc20GetUserScaledCrossBorrowInGroup(groupData, user);
        totalScaledIsolateBorrow += VaultLogic.erc20GetUserScaledIsolateBorrowInGroup(groupData, user);
      }
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      totalScaledCrossSupply = VaultLogic.erc721GetUserCrossSupply(assetData, user);
      totalScaledIsolateSupply = VaultLogic.erc721GetUserIsolateSupply(assetData, user);
    }
  }

  function getUserAssetGroupData(
    address user,
    uint32 poolId,
    address asset,
    uint8 groupId
  )
    public
    view
    returns (
      uint256 totalScaledCrossBorrow,
      uint256 totalCrossBorrow,
      uint256 totalScaledIsolateBorrow,
      uint256 totalIsolateBorrow
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[groupId];

    totalScaledCrossBorrow = VaultLogic.erc20GetUserScaledCrossBorrowInGroup(groupData, user);
    totalScaledIsolateBorrow = VaultLogic.erc20GetUserScaledIsolateBorrowInGroup(groupData, user);

    uint256 index = InterestLogic.getNormalizedBorrowDebt(assetData, groupData);
    totalCrossBorrow = VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, user, index);
    totalIsolateBorrow = VaultLogic.erc20GetUserIsolateBorrowInGroup(groupData, user, index);
  }

  function getUserAccountDebtData(
    address user,
    uint32 poolId
  )
    public
    view
    returns (
      uint256[] memory groupsCollateralInBase,
      uint256[] memory groupsBorrowInBase,
      uint256[] memory groupsAvailableBorrowInBase
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    ResultTypes.UserAccountResult memory result = GenericLogic.calculateUserAccountDataForHeathFactor(
      poolData,
      user,
      ps.priceOracle
    );

    groupsCollateralInBase = result.allGroupsCollateralInBaseCurrency;
    groupsBorrowInBase = result.allGroupsDebtInBaseCurrency;

    groupsAvailableBorrowInBase = new uint256[](result.allGroupsCollateralInBaseCurrency.length);

    for (uint256 i = 0; i < result.allGroupsCollateralInBaseCurrency.length; i++) {
      groupsAvailableBorrowInBase[i] = GenericLogic.calculateAvailableBorrows(
        result.allGroupsCollateralInBaseCurrency[i],
        result.allGroupsDebtInBaseCurrency[i],
        result.allGroupsAvgLtv[i]
      );
    }
  }

  function getIsolateCollateralData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId,
    address debtAsset
  ) public view returns (uint256 totalCollateral, uint256 totalBorrow, uint256 availableBorrow, uint256 healthFactor) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    DataTypes.AssetData storage nftAssetData = poolData.assetLookup[nftAsset];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[debtAsset];
    DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[nftAssetData.classGroup];
    DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[nftAsset][tokenId];

    ResultTypes.NftLoanResult memory nftLoanResult = GenericLogic.calculateNftLoanData(
      poolData,
      debtAssetData,
      debtGroupData,
      nftAssetData,
      loanData,
      ps.priceOracle
    );

    totalCollateral =
      (nftLoanResult.totalCollateralInBaseCurrency * (10 ** debtAssetData.underlyingDecimals)) /
      nftLoanResult.debtAssetPriceInBaseCurrency;
    totalBorrow =
      (nftLoanResult.totalDebtInBaseCurrency * (10 ** debtAssetData.underlyingDecimals)) /
      nftLoanResult.debtAssetPriceInBaseCurrency;
    availableBorrow = GenericLogic.calculateAvailableBorrows(
      totalCollateral,
      totalBorrow,
      nftAssetData.collateralFactor
    );

    healthFactor = nftLoanResult.healthFactor;
  }

  function getIsolateLoanData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId
  )
    public
    view
    returns (address reserveAsset, uint256 scaledAmount, uint256 borrowAmount, uint8 reserveGroup, uint8 loanStatus)
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[nftAsset][tokenId];
    if (loanData.reserveAsset == address(0)) {
      return (address(0), 0, 0, 0, 0);
    }

    DataTypes.AssetData storage assetData = poolData.assetLookup[loanData.reserveAsset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[loanData.reserveGroup];

    reserveAsset = loanData.reserveAsset;
    scaledAmount = loanData.scaledAmount;
    borrowAmount = scaledAmount.rayMul(InterestLogic.getNormalizedBorrowDebt(assetData, groupData));
    reserveGroup = loanData.reserveGroup;
    loanStatus = loanData.loanStatus;
  }

  function getIsolateAuctionData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId
  )
    public
    view
    returns (
      uint40 bidStartTimestamp,
      uint40 bidEndTimestamp,
      address firstBidder,
      address lastBidder,
      uint256 bidAmount,
      uint256 bidFine,
      uint256 redeemAmount
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[nftAsset][tokenId];
    if (loanData.loanStatus != Constants.LOAN_STATUS_AUCTION) {
      return (0, 0, address(0), address(0), 0, 0, 0);
    }

    DataTypes.AssetData storage nftAssetData = poolData.assetLookup[nftAsset];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[loanData.reserveAsset];
    DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[loanData.reserveGroup];

    bidStartTimestamp = loanData.bidStartTimestamp;
    bidEndTimestamp = loanData.bidStartTimestamp + nftAssetData.auctionDuration;
    firstBidder = loanData.firstBidder;
    lastBidder = loanData.lastBidder;
    bidAmount = loanData.bidAmount;

    (, bidFine) = GenericLogic.calculateNftLoanBidFine(
      poolData,
      debtAssetData,
      debtGroupData,
      nftAssetData,
      loanData,
      ps.priceOracle
    );

    uint256 normalizedIndex = InterestLogic.getNormalizedBorrowDebt(debtAssetData, debtGroupData);
    uint256 borrowAmount = loanData.scaledAmount.rayMul(normalizedIndex);
    redeemAmount = borrowAmount.percentMul(nftAssetData.redeemThreshold);
  }

  function getYieldERC20BorrowBalance(uint32 poolId, address asset, address staker) public view returns (uint256) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroup];

    uint256 scaledBalance = VaultLogic.erc20GetUserScaledCrossBorrowInGroup(groupData, staker);
    return scaledBalance.rayMul(InterestLogic.getNormalizedBorrowDebt(assetData, groupData));
  }
}
