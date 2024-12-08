// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BaseModule} from '../base/BaseModule.sol';

import {Constants} from '../libraries/helpers/Constants.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {InputTypes} from '../libraries/types/InputTypes.sol';

import {StorageSlot} from '../libraries/logic/StorageSlot.sol';
import {VaultLogic} from '../libraries/logic/VaultLogic.sol';
import {QueryLogic} from '../libraries/logic/QueryLogic.sol';
import {LiquidationLogic} from '../libraries/logic/LiquidationLogic.sol';

/// @notice Pool Query Service Logic
contract PoolLens is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__POOL_LENS, moduleGitCommit_) {}

  function getPoolMaxAssetNumber() public pure returns (uint256) {
    return QueryLogic.getPoolMaxAssetNumber();
  }

  function getPoolMaxGroupNumber() public pure returns (uint256) {
    return QueryLogic.getPoolMaxGroupNumber();
  }

  function getPoolList() public view returns (uint256[] memory) {
    return QueryLogic.getPoolList();
  }

  function getPoolName(uint32 poolId) public view returns (string memory) {
    return QueryLogic.getPoolName(poolId);
  }

  function getPoolConfigFlag(
    uint32 poolId
  ) public view returns (bool isPaused, bool isYieldEnabled, bool isYieldPaused, uint8 yieldGroup) {
    return QueryLogic.getPoolConfigFlag(poolId);
  }

  function getPoolGroupList(uint32 poolId) public view returns (uint256[] memory) {
    return QueryLogic.getPoolGroupList(poolId);
  }

  function getPoolAssetList(uint32 poolId) public view returns (address[] memory assets, uint8[] memory types) {
    return QueryLogic.getPoolAssetList(poolId);
  }

  function getAssetGroupList(uint32 poolId, address asset) public view returns (uint256[] memory) {
    return QueryLogic.getAssetGroupList(poolId, asset);
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
    return QueryLogic.getAssetConfigFlag(poolId, asset);
  }

  function getAssetConfigCap(
    uint32 poolId,
    address asset
  ) public view returns (uint256 supplyCap, uint256 borrowCap, uint256 yieldCap) {
    return QueryLogic.getAssetConfigCap(poolId, asset);
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
    return QueryLogic.getAssetLendingConfig(poolId, asset);
  }

  function getAssetAuctionConfig(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (uint16 redeemThreshold, uint16 bidFineFactor, uint16 minBidFineFactor, uint40 auctionDuration)
  {
    return QueryLogic.getAssetAuctionConfig(poolId, asset);
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
    return QueryLogic.getAssetSupplyData(poolId, asset);
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
    return QueryLogic.getAssetGroupData(poolId, asset, group);
  }

  function getAssetFeeData(
    uint32 poolId,
    address asset
  ) public view returns (uint256 feeFactor, uint256 accruedFee, uint256 normAccruedFee) {
    return QueryLogic.getAssetFeeData(poolId, asset);
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
      uint256 avgLtv,
      uint256 avgLiquidationThreshold,
      uint256 healthFactor
    )
  {
    return QueryLogic.getUserAccountData(user, poolId);
  }

  function getUserCrossLiquidateData(
    uint32 poolId,
    address borrower,
    address collateralAsset,
    uint256 collateralAmount,
    address debtAsset,
    uint256 debtAmount
  ) public view returns (uint256 actualCollateralToLiquidate, uint256 actualDebtToLiquidate) {
    return
      LiquidationLogic.viewGetUserCrossLiquidateData(
        InputTypes.ViewGetUserCrossLiquidateDataParams({
          poolId: poolId,
          borrower: borrower,
          collateralAsset: collateralAsset,
          collateralAmount: collateralAmount,
          debtAsset: debtAsset,
          debtAmount: debtAmount
        })
      );
  }

  function getUserAssetList(
    address user,
    uint32 poolId
  ) public view returns (address[] memory suppliedAssets, address[] memory borrowedAssets) {
    return QueryLogic.getUserAssetList(user, poolId);
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
    return QueryLogic.getUserAssetData(user, poolId, asset);
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
    return QueryLogic.getUserAssetScaledData(user, poolId, asset);
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
    return QueryLogic.getUserAssetGroupData(user, poolId, asset, groupId);
  }

  function getUserAccountGroupData(
    address user,
    uint32 poolId
  )
    public
    view
    returns (
      uint256[] memory groupsIds,
      uint256[] memory groupsCollateralInBase,
      uint256[] memory groupsBorrowInBase,
      uint256[] memory groupsAvailableBorrowInBase
    )
  {
    return QueryLogic.getUserAccountGroupData(user, poolId);
  }

  function getIsolateCollateralData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId,
    address debtAsset
  ) public view returns (uint256 totalCollateral, uint256 totalBorrow, uint256 availableBorrow, uint256 healthFactor) {
    return QueryLogic.getIsolateCollateralData(poolId, nftAsset, tokenId, debtAsset);
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
    return QueryLogic.getIsolateLoanData(poolId, nftAsset, tokenId);
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
    return QueryLogic.getIsolateAuctionData(poolId, nftAsset, tokenId);
  }

  function getIsolateLiquidateData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId
  ) public view returns (uint256 borrowAmount, uint256 thresholdPrice, uint256 liquidatePrice) {
    return QueryLogic.getIsolateLiquidateData(poolId, nftAsset, tokenId);
  }

  function getYieldERC20BorrowBalance(uint32 poolId, address asset, address staker) public view returns (uint256) {
    return QueryLogic.getYieldERC20BorrowBalance(poolId, asset, staker);
  }

  function getYieldStakerAssetData(
    uint32 poolId,
    address asset,
    address staker
  ) public view returns (uint256 stakerCap, uint256 stakerBorrow, uint256 availableBorrow) {
    return QueryLogic.getYieldStakerAssetData(poolId, asset, staker);
  }

  function getERC721TokenData(
    uint32 poolId,
    address asset,
    uint256 tokenId
  ) public view returns (address, uint8, address) {
    return QueryLogic.getERC721TokenData(poolId, asset, tokenId);
  }

  function getERC721Delegations(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata tokenIds
  ) public view returns (address[][] memory) {
    return QueryLogic.getERC721Delegations(poolId, nftAsset, tokenIds);
  }

  function isOperatorAuthorized(
    uint32 poolId,
    address account,
    address asset,
    address operator
  ) public view returns (bool) {
    return QueryLogic.isOperatorAuthorized(poolId, account, asset, operator);
  }
}
