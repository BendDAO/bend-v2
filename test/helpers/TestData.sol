// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import 'src/libraries/helpers/Constants.sol';
import 'src/PoolManager.sol';

contract TestData {
  struct AssetData {
    uint256 totalCrossSupplied;
    uint256 totalIsolateSupplied;
    uint256 availableSupply;
    uint256 supplyRate;
    uint256 supplyIndex;
    // borrow fields based on one group
    uint256 totalCrossBorrow;
    uint256 totalIsolateBorrow;
    uint256 borrowRate;
    uint256 borrowIndex;
  }

  struct UserAssetData {
    uint256 walletBalance;
    uint256 scaledSupplyBlance;
    uint256 supplyBlance;
    // borrow fields based on one group
    uint256 scaledBorrowBlance;
    uint256 borrowBalance;
  }

  struct UserAccountData {
    uint256 totalCollateralInBase;
    uint256 totalBorrowInBase;
    uint256 availableBorrowInBase;
    uint256 currentCollateralFactor;
    uint256 currentLiquidationThreshold;
    uint256 healthFactor;
  }

  PoolManager internal _poolManager;

  constructor(PoolManager poolManager_) {
    _poolManager = poolManager_;
  }

  function getAssetData(uint32 poolId, address asset, uint8 group) public view returns (AssetData memory data) {
    (
      data.totalCrossSupplied,
      data.totalIsolateSupplied,
      data.availableSupply,
      data.supplyRate,
      data.supplyIndex
    ) = _poolManager.getAssetSupplyData(poolId, asset);

    if (group > 0) {
      (data.totalCrossBorrow, data.totalIsolateBorrow, data.borrowRate, data.borrowIndex) = _poolManager
        .getAssetBorrowData(poolId, asset, group);
    }
  }

  function getUserAssetData(
    uint32 poolId,
    address asset,
    uint8 assetType,
    uint8 group,
    address user
  ) public view returns (UserAssetData memory data) {
    if (assetType == Constants.ASSET_TYPE_ERC20) {
      data.walletBalance = ERC20(asset).balanceOf(user);

      data.scaledSupplyBlance = _poolManager.getUserERC20ScaledSupplyBalance(poolId, asset, user);
      data.supplyBlance = _poolManager.getUserERC20SupplyBalance(poolId, asset, user);

      if (group > 0) {
        data.scaledBorrowBlance = _poolManager.getUserERC20ScaledBorrowBalance(poolId, asset, user);
        data.borrowBalance = _poolManager.getUserERC20BorrowBalance(poolId, asset, user);
      }
    } else if (assetType == Constants.ASSET_TYPE_ERC721) {
      data.walletBalance = ERC721(asset).balanceOf(user);

      data.supplyBlance = _poolManager.getUserERC721SupplyBalance(poolId, asset, user);
    }
  }

  function getUserAccountData(uint32 poolId, address user) public view returns (UserAccountData memory data) {
    (
      data.totalCollateralInBase,
      data.totalBorrowInBase,
      data.availableBorrowInBase,
      data.currentCollateralFactor,
      data.currentLiquidationThreshold,
      data.healthFactor
    ) = _poolManager.getUserAccountData(poolId, user);
  }
}
