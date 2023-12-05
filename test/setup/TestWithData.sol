// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';

import {TestWithSetup} from './TestWithSetup.sol';

import 'forge-std/Test.sol';

abstract contract TestWithData is TestWithSetup {
  using WadRayMath for uint256;

  // asset level data
  struct TestGroupData {
    uint256 totalCrossBorrow;
    uint256 totalScaledCrossBorrow;
    uint256 totalIsolateBorrow;
    uint256 totalScaledIsolateBorrow;
    uint256 borrowRate;
    uint256 borrowIndex;
    address rateModel;
    uint256 lastUpdateTimestamp;
  }

  struct TestAssetData {
    address asset;
    uint256 totalScaledCrossSupply;
    uint256 totalCrossSupply;
    uint256 totalScaledIsolateSupply;
    uint256 totalIsolateSupply;
    uint256 availableSupply;
    uint256 supplyRate;
    uint256 supplyIndex;
    uint256 lastUpdateTimestamp;
    TestGroupData[] groupsData;
    uint256 totalCrossBorrow;
    uint256 totalIsolateBorrow;
    uint256 totalLiquidity;
    uint256 utilizationRate;
  }

  // user level data
  struct TestUserAssetData {
    uint256 walletBalance;
    uint256 totalScaledCrossSupply;
    uint256 totalCrossSupply;
    uint256 totalScaledIsolateSupply;
    uint256 totalIsolateSupply;
    uint256 totalCrossBorrow;
    uint256 totalIsolateBorrow;
  }

  struct TestUserGroupData {
    uint256 totalScaledCrossBorrow;
    uint256 totalCrossBorrow;
    uint256 totalScaledIsolateBorrow;
    uint256 totalIsolateBorrow;
  }

  struct TestUserAccountData {
    uint256 totalCollateralInBase;
    uint256 totalBorrowInBase;
    uint256 availableBorrowInBase;
    uint256 currentCollateralFactor;
    uint256 currentLiquidationThreshold;
    uint256 healthFactor;
  }

  struct TestUserData {
    address user;
    TestUserAccountData accountData;
    TestUserAssetData userAssetData;
    TestUserGroupData[] userGroupsData;
  }

  struct TestContractData {
    TestAssetData assetData;
    TestUserData userData;
  }

  function onSetUp() public virtual override {
    super.onSetUp();
  }

  function getAssetData(uint32 poolId, address asset) public view returns (TestAssetData memory assetData) {
    (
      assetData.totalCrossSupply,
      assetData.totalIsolateSupply,
      assetData.availableSupply,
      assetData.supplyRate,
      assetData.supplyIndex,
      assetData.lastUpdateTimestamp
    ) = tsPoolManager.getAssetSupplyData(poolId, asset);

    uint256 maxGroupNum = tsPoolManager.getPoolMaxGroupNumber();
    assetData.groupsData = new TestGroupData[](maxGroupNum);

    uint256[] memory groupIds = tsPoolManager.getAssetGroupList(poolId, asset);
    for (uint256 i = 0; i < groupIds.length; i++) {
      TestGroupData memory groupData = assetData.groupsData[groupIds[i]];
      (
        groupData.totalCrossBorrow,
        groupData.totalIsolateBorrow,
        groupData.borrowRate,
        groupData.borrowIndex,
        groupData.rateModel,
        groupData.lastUpdateTimestamp
      ) = tsPoolManager.getAssetGroupData(poolId, asset, uint8(groupIds[i]));

      assetData.totalCrossBorrow += groupData.totalCrossBorrow;
      assetData.totalIsolateBorrow += groupData.totalIsolateBorrow;
    }

    assetData.totalLiquidity = assetData.totalCrossBorrow + assetData.totalIsolateBorrow + assetData.availableSupply;
    if (assetData.totalLiquidity > 0) {
      assetData.utilizationRate =
        (assetData.totalCrossBorrow + assetData.totalIsolateBorrow) /
        assetData.totalLiquidity;
    }
  }

  function getUserAccountData(uint32 poolId, address user) public view returns (TestUserAccountData memory data) {
    (
      data.totalCollateralInBase,
      data.totalBorrowInBase,
      data.availableBorrowInBase,
      data.currentCollateralFactor,
      data.currentLiquidationThreshold,
      data.healthFactor
    ) = tsPoolManager.getUserAccountData(poolId, user);
  }

  function getUserData(
    address user,
    uint32 poolId,
    address asset,
    uint8 assetType
  ) public view returns (TestUserData memory userData) {
    userData.accountData = getUserAccountData(poolId, user);

    if (assetType == Constants.ASSET_TYPE_ERC20) {
      userData.userAssetData.walletBalance = ERC20(asset).balanceOf(user);
    } else if (assetType == Constants.ASSET_TYPE_ERC721) {
      userData.userAssetData.walletBalance = ERC721(asset).balanceOf(user);
    }

    (
      userData.userAssetData.totalCrossSupply,
      userData.userAssetData.totalIsolateSupply,
      userData.userAssetData.totalCrossBorrow,
      userData.userAssetData.totalIsolateBorrow
    ) = tsPoolManager.getUserAssetData(user, poolId, asset);

    uint256 maxGroupNum = tsPoolManager.getPoolMaxGroupNumber();
    userData.userGroupsData = new TestUserGroupData[](maxGroupNum);

    uint256[] memory groupIds = tsPoolManager.getAssetGroupList(poolId, asset);
    for (uint256 i = 0; i < groupIds.length; i++) {
      TestUserGroupData memory groupData = userData.userGroupsData[i];
      (groupData.totalCrossBorrow, groupData.totalIsolateBorrow) = tsPoolManager.getUserAssetGroupData(
        user,
        poolId,
        asset,
        uint8(groupIds[i])
      );
    }
  }

  function getContractData(
    address user,
    uint32 poolId,
    address asset,
    uint8 assetType
  ) internal view returns (TestContractData memory data) {
    data.assetData = getAssetData(poolId, asset);
    data.userData = getUserData(user, poolId, asset, assetType);
  }
}
