// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BaseModule} from '../base/BaseModule.sol';

import {Constants} from '../libraries/helpers/Constants.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {InputTypes} from '../libraries/types/InputTypes.sol';
import {ResultTypes} from '../libraries/types/ResultTypes.sol';

import {StorageSlot} from '../libraries/logic/StorageSlot.sol';
import {VaultLogic} from '../libraries/logic/VaultLogic.sol';
import {QueryLogic} from '../libraries/logic/QueryLogic.sol';
import {LiquidationLogic} from '../libraries/logic/LiquidationLogic.sol';

/// @notice Pool Query Service Logic for UI
contract UIPoolLens is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__UI_POOL_LENS, moduleGitCommit_) {}

  /* @dev calcType: 1-supply, 2-withdraw, 3-borrow, 4-repay */
  function getUserAccountDataForCalculation(
    address user,
    uint32 poolId,
    uint8 calcType,
    address asset,
    uint256 amount
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
    return QueryLogic.getUserAccountDataForCalculation(user, poolId, calcType, asset, amount);
  }

  /* @dev calcType: 3-borrow, 4-repay */
  function getIsolateCollateralDataForCalculation(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId,
    uint8 calcType,
    address debtAsset,
    uint256 amount
  ) public view returns (ResultTypes.IsolateCollateralDataResult memory dataResult) {
    return QueryLogic.getIsolateCollateralDataForCalculation(poolId, nftAsset, tokenId, calcType, debtAsset, amount);
  }

  function getIsolateCollateralDataList(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[] calldata tokenIds,
    address[] calldata debtAssets
  )
    public
    view
    returns (
      uint256[] memory totalCollaterals,
      uint256[] memory totalBorrows,
      uint256[] memory availableBorrows,
      uint256[] memory healthFactors
    )
  {
    totalCollaterals = new uint256[](nftAssets.length);
    totalBorrows = new uint256[](nftAssets.length);
    availableBorrows = new uint256[](nftAssets.length);
    healthFactors = new uint256[](nftAssets.length);

    for (uint i = 0; i < nftAssets.length; i++) {
      (totalCollaterals[i], totalBorrows[i], availableBorrows[i], healthFactors[i]) = QueryLogic
        .getIsolateCollateralData(poolId, nftAssets[i], tokenIds[i], debtAssets[i]);
    }
  }

  function getIsolateLoanDataList(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[] calldata tokenIds
  )
    public
    view
    returns (
      address[] memory reserveAssets,
      uint256[] memory scaledAmounts,
      uint256[] memory borrowAmounts,
      uint8[] memory reserveGroups,
      uint8[] memory loanStatuses
    )
  {
    reserveAssets = new address[](nftAssets.length);
    scaledAmounts = new uint256[](nftAssets.length);
    borrowAmounts = new uint256[](nftAssets.length);
    reserveGroups = new uint8[](nftAssets.length);
    loanStatuses = new uint8[](nftAssets.length);

    for (uint i = 0; i < nftAssets.length; i++) {
      (reserveAssets[i], scaledAmounts[i], borrowAmounts[i], reserveGroups[i], loanStatuses[i]) = QueryLogic
        .getIsolateLoanData(poolId, nftAssets[i], tokenIds[i]);
    }
  }

  function getIsolateAuctionDataList(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[] calldata tokenIds
  )
    public
    view
    returns (
      uint40[] memory bidStartTimestamps,
      uint40[] memory bidEndTimestamps,
      address[] memory firstBidders,
      address[] memory lastBidders,
      uint256[] memory bidAmounts,
      uint256[] memory bidFines,
      uint256[] memory redeemAmounts
    )
  {
    bidStartTimestamps = new uint40[](nftAssets.length);
    bidEndTimestamps = new uint40[](nftAssets.length);
    firstBidders = new address[](nftAssets.length);
    lastBidders = new address[](nftAssets.length);
    bidAmounts = new uint256[](nftAssets.length);
    bidFines = new uint256[](nftAssets.length);
    redeemAmounts = new uint256[](nftAssets.length);

    for (uint i = 0; i < nftAssets.length; i++) {
      (
        bidStartTimestamps[i],
        bidEndTimestamps[i],
        firstBidders[i],
        lastBidders[i],
        bidAmounts[i],
        bidFines[i],
        redeemAmounts[i]
      ) = QueryLogic.getIsolateAuctionData(poolId, nftAssets[i], tokenIds[i]);
    }
  }

  function getERC721TokenDataList(
    uint32 poolId,
    address[] calldata assets,
    uint256[] calldata tokenIds
  ) public view returns (address[] memory owners, uint8[] memory supplyModes, address[] memory lockerAddrs) {
    owners = new address[](assets.length);
    supplyModes = new uint8[](assets.length);
    lockerAddrs = new address[](assets.length);

    for (uint i = 0; i < assets.length; i++) {
      (owners[i], supplyModes[i], lockerAddrs[i]) = QueryLogic.getERC721TokenData(poolId, assets[i], tokenIds[i]);
    }
  }
}
