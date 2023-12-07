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

  // asset level config
  struct TestAssetConfig {
    uint16 feeFactor;
    uint16 collateralFactor;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
  }

  // asset level data
  struct TestGroupData {
    // fields come from contract
    uint256 totalScaledCrossBorrow;
    uint256 totalCrossBorrow;
    uint256 totalScaledIsolateBorrow;
    uint256 totalIsolateBorrow;
    uint256 borrowRate;
    uint256 borrowIndex;
    address rateModel;
    uint256 lastUpdateTimestamp;
    // fields not come from contract
    uint256 totalBorrow;
  }

  struct TestAssetData {
    address asset;
    TestAssetConfig config;
    // fields come from contract
    uint256 totalScaledCrossSupply;
    uint256 totalCrossSupply;
    uint256 totalScaledIsolateSupply;
    uint256 totalIsolateSupply;
    uint256 availableSupply;
    uint256 supplyRate;
    uint256 supplyIndex;
    uint256 lastUpdateTimestamp;
    TestGroupData[] groupsData;
    // fields not come from contract
    uint256 totalSupply;
    uint256 totalCrossBorrow;
    uint256 totalIsolateBorrow;
    uint256 totalBorrow;
    uint256 totalLiquidity;
    uint256 utilizationRate;
  }

  // user level data
  struct TestUserGroupData {
    // fields come from contract
    uint256 totalScaledCrossBorrow;
    uint256 totalCrossBorrow;
    uint256 totalScaledIsolateBorrow;
    uint256 totalIsolateBorrow;
    // fields not come from contract
    uint256 totalBorrow;
  }

  struct TestUserAssetData {
    address user;
    // fields come from contract
    uint256 walletBalance;
    uint256 totalScaledCrossSupply;
    uint256 totalCrossSupply;
    uint256 totalScaledIsolateSupply;
    uint256 totalIsolateSupply;
    uint256 totalScaledCrossBorrow;
    uint256 totalCrossBorrow;
    uint256 totalScaledIsolateBorrow;
    uint256 totalIsolateBorrow;
    TestUserGroupData[] groupsData;
    // fields not come from contract
    uint256 totalSupply;
    uint256 totalBorrow;
  }

  struct TestUserAccountData {
    // fields come from contract
    uint256 totalCollateralInBase;
    uint256 totalBorrowInBase;
    uint256 availableBorrowInBase;
    uint256 currentCollateralFactor;
    uint256 currentLiquidationThreshold;
    uint256 healthFactor;
    // fields not come from contract
  }

  struct TestContractData {
    TestAssetData assetData;
    TestUserAssetData userAssetData;
    TestUserAccountData accountData;
  }

  function onSetUp() public virtual override {
    super.onSetUp();
  }

  function getAssetData(
    uint32 poolId,
    address asset,
    uint8 /*assetType*/
  ) public view returns (TestAssetData memory assetData) {
    (
      assetData.config.feeFactor,
      assetData.config.collateralFactor,
      assetData.config.liquidationThreshold,
      assetData.config.liquidationBonus
    ) = tsPoolManager.getAssetLendingConfig(poolId, asset);

    (
      assetData.totalCrossSupply,
      assetData.totalIsolateSupply,
      assetData.availableSupply,
      assetData.supplyRate,
      assetData.supplyIndex,
      assetData.lastUpdateTimestamp
    ) = tsPoolManager.getAssetSupplyData(poolId, asset);
    assetData.totalSupply = assetData.totalCrossSupply + assetData.totalIsolateSupply;

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
      groupData.totalBorrow = groupData.totalCrossBorrow + groupData.totalIsolateBorrow;

      assetData.totalCrossBorrow += groupData.totalCrossBorrow;
      assetData.totalIsolateBorrow += groupData.totalIsolateBorrow;
    }

    assetData.totalBorrow = assetData.totalCrossBorrow + assetData.totalIsolateBorrow;
    assetData.totalLiquidity = assetData.totalBorrow + assetData.availableSupply;
    if (assetData.totalLiquidity > 0) {
      assetData.utilizationRate = assetData.totalBorrow.rayDiv(assetData.totalLiquidity);
    }
  }

  function copyAssetData(TestAssetData memory assetDataOld) public view returns (TestAssetData memory assetDataNew) {
    if (_debugFlag) console.log('copyAssetData', 'begin');

    // just refer to the original config
    assetDataNew.config = assetDataOld.config;

    assetDataNew.totalScaledCrossSupply = assetDataOld.totalScaledCrossSupply;
    assetDataNew.totalCrossSupply = assetDataOld.totalCrossSupply;
    assetDataNew.totalScaledIsolateSupply = assetDataOld.totalScaledIsolateSupply;
    assetDataNew.totalIsolateSupply = assetDataOld.totalIsolateSupply;
    assetDataNew.availableSupply = assetDataOld.availableSupply;
    assetDataNew.supplyRate = assetDataOld.supplyRate;
    assetDataNew.supplyIndex = assetDataOld.supplyIndex;
    assetDataNew.lastUpdateTimestamp = assetDataOld.lastUpdateTimestamp;

    assetDataNew.groupsData = new TestGroupData[](assetDataOld.groupsData.length);
    for (uint256 i = 0; i < assetDataOld.groupsData.length; i++) {
      TestGroupData memory groupDataOld = assetDataOld.groupsData[i];
      TestGroupData memory groupDataNew = assetDataNew.groupsData[i];

      groupDataNew.totalScaledCrossBorrow = groupDataOld.totalScaledCrossBorrow;
      groupDataNew.totalCrossBorrow = groupDataOld.totalCrossBorrow;
      groupDataNew.totalScaledIsolateBorrow = groupDataOld.totalScaledIsolateBorrow;
      groupDataNew.totalIsolateBorrow = groupDataOld.totalIsolateBorrow;
      groupDataNew.borrowRate = groupDataOld.borrowRate;
      groupDataNew.borrowIndex = groupDataOld.borrowIndex;
      groupDataNew.rateModel = groupDataOld.rateModel;
      groupDataNew.lastUpdateTimestamp = groupDataOld.lastUpdateTimestamp;

      groupDataNew.totalBorrow = groupDataOld.totalBorrow;
    }

    assetDataNew.totalSupply = assetDataOld.totalSupply;
    assetDataNew.totalCrossBorrow = assetDataOld.totalCrossBorrow;
    assetDataNew.totalIsolateBorrow = assetDataOld.totalIsolateBorrow;
    assetDataNew.totalBorrow = assetDataOld.totalBorrow;
    assetDataNew.totalLiquidity = assetDataOld.totalLiquidity;
    assetDataNew.utilizationRate = assetDataOld.utilizationRate;

    if (_debugFlag) console.log('copyAssetData', 'end');
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

  function getUserAssetData(
    address user,
    uint32 poolId,
    address asset,
    uint8 assetType
  ) public view returns (TestUserAssetData memory userAssetData) {
    if (assetType == Constants.ASSET_TYPE_ERC20) {
      userAssetData.walletBalance = ERC20(asset).balanceOf(user);
    } else if (assetType == Constants.ASSET_TYPE_ERC721) {
      userAssetData.walletBalance = ERC721(asset).balanceOf(user);
    }

    (
      userAssetData.totalCrossSupply,
      userAssetData.totalIsolateSupply,
      userAssetData.totalCrossBorrow,
      userAssetData.totalIsolateBorrow
    ) = tsPoolManager.getUserAssetData(user, poolId, asset);
    userAssetData.totalSupply = userAssetData.totalCrossSupply + userAssetData.totalIsolateSupply;
    userAssetData.totalBorrow = userAssetData.totalCrossBorrow + userAssetData.totalIsolateBorrow;

    uint256 maxGroupNum = tsPoolManager.getPoolMaxGroupNumber();
    userAssetData.groupsData = new TestUserGroupData[](maxGroupNum);

    uint256[] memory groupIds = tsPoolManager.getAssetGroupList(poolId, asset);
    for (uint256 i = 0; i < groupIds.length; i++) {
      TestUserGroupData memory groupData = userAssetData.groupsData[groupIds[i]];
      (groupData.totalCrossBorrow, groupData.totalIsolateBorrow) = tsPoolManager.getUserAssetGroupData(
        user,
        poolId,
        asset,
        uint8(groupIds[i])
      );
      groupData.totalBorrow = groupData.totalCrossBorrow + groupData.totalIsolateBorrow;
    }
  }

  function copyUserAssetData(
    TestUserAssetData memory userAssetDataOld
  ) public view returns (TestUserAssetData memory userAssetDataNew) {
    if (_debugFlag) console.log('copyUserAssetData', 'begin');

    userAssetDataNew.walletBalance = userAssetDataOld.walletBalance;
    userAssetDataNew.totalScaledCrossSupply = userAssetDataOld.totalScaledCrossSupply;
    userAssetDataNew.totalCrossSupply = userAssetDataOld.totalCrossSupply;
    userAssetDataNew.totalScaledIsolateSupply = userAssetDataOld.totalScaledIsolateSupply;
    userAssetDataNew.totalIsolateSupply = userAssetDataOld.totalIsolateSupply;

    userAssetDataNew.totalSupply = userAssetDataOld.totalSupply;

    userAssetDataNew.groupsData = new TestUserGroupData[](userAssetDataOld.groupsData.length);
    for (uint256 i = 0; i < userAssetDataOld.groupsData.length; i++) {
      TestUserGroupData memory groupDataOld = userAssetDataOld.groupsData[i];
      TestUserGroupData memory groupDataNew = userAssetDataNew.groupsData[i];

      groupDataNew.totalScaledCrossBorrow = groupDataOld.totalScaledCrossBorrow;
      groupDataNew.totalCrossBorrow = groupDataOld.totalCrossBorrow;
      groupDataNew.totalScaledIsolateBorrow = groupDataOld.totalScaledIsolateBorrow;
      groupDataNew.totalIsolateBorrow = groupDataOld.totalIsolateBorrow;

      groupDataNew.totalBorrow = groupDataOld.totalBorrow;
    }

    userAssetDataNew.totalBorrow = userAssetDataOld.totalBorrow;

    if (_debugFlag) console.log('copyUserAssetData', 'end');
  }

  function getContractData(
    address user,
    uint32 poolId,
    address asset,
    uint8 assetType
  ) internal view returns (TestContractData memory data) {
    data.assetData = getAssetData(poolId, asset, assetType);
    data.userAssetData = getUserAssetData(user, poolId, asset, assetType);
  }

  function getContractDataWithAccout(
    address user,
    uint32 poolId,
    address asset,
    uint8 assetType
  ) internal view returns (TestContractData memory data) {
    data.assetData = getAssetData(poolId, asset, assetType);
    data.userAssetData = getUserAssetData(user, poolId, asset, assetType);
    data.accountData = getUserAccountData(poolId, user);
  }
}
