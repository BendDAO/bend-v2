// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';
import {WadRayMath} from '../math/WadRayMath.sol';

import 'forge-std/console.sol';

library VaultLogic {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using WadRayMath for uint256;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

  //////////////////////////////////////////////////////////////////////////////
  // Account methods
  //////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Add or remove user borrowed asset which used for flag.
   */
  function accountSetBorrowedAsset(DataTypes.AccountData storage accountData, address asset, bool borrowing) internal {
    if (borrowing) {
      accountData.borrowedAssets.add(asset);
    } else {
      accountData.borrowedAssets.remove(asset);
    }
  }

  function accoutHasBorrowedAsset(
    DataTypes.AccountData storage accountData,
    address asset
  ) internal view returns (bool) {
    return accountData.borrowedAssets.contains(asset);
  }

  function accountGetBorrowedAssets(
    DataTypes.AccountData storage accountData
  ) internal view returns (address[] memory) {
    return accountData.borrowedAssets.values();
  }

  function accountCheckAndSetBorrowedAsset(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address account
  ) internal {
    DataTypes.AccountData storage accountData = poolData.accountLookup[account];
    uint256 totalBorrow = erc20GetUserScaledCrossBorrowInAsset(poolData, assetData, account);
    if (totalBorrow == 0) {
      accountSetBorrowedAsset(accountData, assetData.underlyingAsset, false);
    } else {
      accountSetBorrowedAsset(accountData, assetData.underlyingAsset, true);
    }
  }

  /**
   * @dev Add or remove user supplied asset which used for flag.
   */
  function accountSetSuppliedAsset(
    DataTypes.AccountData storage accountData,
    address asset,
    bool usingAsCollateral
  ) internal {
    if (usingAsCollateral) {
      accountData.suppliedAssets.add(asset);
    } else {
      accountData.suppliedAssets.remove(asset);
    }
  }

  function accoutHasSuppliedAsset(
    DataTypes.AccountData storage accountData,
    address asset
  ) internal view returns (bool) {
    return accountData.suppliedAssets.contains(asset);
  }

  function accountGetSuppliedAssets(
    DataTypes.AccountData storage accountData
  ) internal view returns (address[] memory) {
    return accountData.suppliedAssets.values();
  }

  function accountCheckAndSetSuppliedAsset(
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address account
  ) internal {
    DataTypes.AccountData storage accountData = poolData.accountLookup[account];

    uint256 totalSupply;
    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      totalSupply = erc20GetUserScaledCrossSupply(assetData, account);
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      totalSupply = erc721GetUserCrossSupply(assetData, account);
    } else {
      revert(Errors.INVALID_ASSET_TYPE);
    }

    if (totalSupply == 0) {
      accountSetSuppliedAsset(accountData, assetData.underlyingAsset, false);
    } else {
      accountSetSuppliedAsset(accountData, assetData.underlyingAsset, true);
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  // ERC20 methods
  //////////////////////////////////////////////////////////////////////////////
  /**
   * @dev Get user supply balance, make sure the index already updated.
   */
  function erc20GetTotalCrossSupply(
    DataTypes.AssetData storage assetData,
    uint256 index
  ) internal view returns (uint256) {
    return assetData.totalScaledCrossSupplied.rayMul(index);
  }

  function erc20GetTotalIsolateSupply(
    DataTypes.AssetData storage assetData,
    uint256 index
  ) internal view returns (uint256) {
    return assetData.totalScaledIsolateSupplied.rayMul(index);
  }

  function erc20GetTotalScaledCrossSupply(DataTypes.AssetData storage assetData) internal view returns (uint256) {
    return assetData.totalScaledCrossSupplied;
  }

  function erc20GetTotalScaledIsolateSupply(DataTypes.AssetData storage assetData) internal view returns (uint256) {
    return assetData.totalScaledIsolateSupplied;
  }

  /**
   * @dev Get user scaled supply balance not related to the index.
   */
  function erc20GetUserScaledCrossSupply(
    DataTypes.AssetData storage assetData,
    address account
  ) internal view returns (uint256) {
    return assetData.userScaledCrossSupplied[account];
  }

  /**
   * @dev Get user supply balance, make sure the index already updated.
   */
  function erc20GetUserIsolateSupply(
    DataTypes.AssetData storage assetData,
    address account,
    uint256 index
  ) internal view returns (uint256) {
    return assetData.userScaledIsolateSupplied[account].rayMul(index);
  }

  /**
   * @dev Get user scaled supply balance not related to the index.
   */
  function erc20GetUserScaledIsolateSupply(
    DataTypes.AssetData storage assetData,
    address account
  ) internal view returns (uint256) {
    return assetData.userScaledIsolateSupplied[account];
  }

  /**
   * @dev Get user supply balance, make sure the index already updated.
   */
  function erc20GetUserCrossSupply(
    DataTypes.AssetData storage assetData,
    address account,
    uint256 index
  ) internal view returns (uint256) {
    return assetData.userScaledCrossSupplied[account].rayMul(index);
  }

  /**
   * @dev Increase user supply balance, make sure the index already updated.
   */
  function erc20IncreaseCrossSupply(DataTypes.AssetData storage assetData, address account, uint256 amount) internal {
    uint256 amountScaled = amount.rayDiv(assetData.supplyIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    assetData.totalScaledCrossSupplied += amountScaled;
    assetData.userScaledCrossSupplied[account] += amountScaled;
  }

  /**
   * @dev Decrease user supply balance, make sure the index already updated.
   */
  function erc20DecreaseCrossSupply(DataTypes.AssetData storage assetData, address account, uint256 amount) internal {
    uint256 amountScaled = amount.rayDiv(assetData.supplyIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    assetData.totalScaledCrossSupplied -= amountScaled;
    assetData.userScaledCrossSupplied[account] -= amountScaled;
  }

  /**
   * @dev Transfer user supply balance, make sure the index already updated.
   */
  function erc20TransferCrossSupply(
    DataTypes.AssetData storage assetData,
    address from,
    address to,
    uint256 amount
  ) internal {
    uint256 amountScaled = amount.rayDiv(assetData.supplyIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    assetData.userScaledCrossSupplied[from] -= amountScaled;
    assetData.userScaledCrossSupplied[to] += amountScaled;
  }

  /**
   * @dev Get total borrow balance in the group, make sure the index already updated.
   */
  function erc20GetTotalCrossBorrowInGroup(
    DataTypes.GroupData storage groupData,
    uint256 index
  ) internal view returns (uint256) {
    return groupData.totalScaledCrossBorrowed.rayMul(index);
  }

  function erc20GetTotalScaledCrossBorrowInGroup(
    DataTypes.GroupData storage groupData
  ) internal view returns (uint256) {
    return groupData.totalScaledCrossBorrowed;
  }

  /**
   * @dev Get total borrow balance in the group, make sure the index already updated.
   */
  function erc20GetTotalIsolateBorrowInGroup(
    DataTypes.GroupData storage groupData,
    uint256 index
  ) internal view returns (uint256) {
    return groupData.totalScaledIsolateBorrowed.rayMul(index);
  }

  function erc20GetTotalScaledIsolateBorrowInGroup(
    DataTypes.GroupData storage groupData
  ) internal view returns (uint256) {
    return groupData.totalScaledIsolateBorrowed;
  }

  /**
   * @dev Get user scaled borrow balance in the group not related to the index.
   */
  function erc20GetUserScaledCrossBorrowInGroup(
    DataTypes.GroupData storage groupData,
    address account
  ) internal view returns (uint256) {
    return groupData.userScaledCrossBorrowed[account];
  }

  /**
   * @dev Get user scaled borrow balance in the asset not related to the index.
   */
  function erc20GetUserScaledCrossBorrowInAsset(
    DataTypes.PoolData storage /*poolData*/,
    DataTypes.AssetData storage assetData,
    address account
  ) internal view returns (uint256) {
    uint256 totalScaledBorrow;

    uint256[] memory groupIds = assetData.groupList.values();
    for (uint256 i = 0; i < groupIds.length; i++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(groupIds[i])];

      uint256 amountScaled = groupData.userScaledCrossBorrowed[account];
      totalScaledBorrow += amountScaled;
    }

    return totalScaledBorrow;
  }

  /**
   * @dev Get user borrow balance in the group, make sure the index already updated.
   */
  function erc20GetUserCrossBorrowInGroup(
    DataTypes.GroupData storage groupData,
    address account,
    uint256 index
  ) internal view returns (uint256) {
    return groupData.userScaledCrossBorrowed[account].rayMul(index);
  }

  /**
   * @dev Get user borrow balance in the asset, make sure the index already updated.
   */
  function erc20GetUserCrossBorrowInAsset(
    DataTypes.PoolData storage /*poolData*/,
    DataTypes.AssetData storage assetData,
    address account
  ) internal view returns (uint256) {
    uint256 totalBorrow;

    uint256[] memory groupIds = assetData.groupList.values();
    for (uint256 i = 0; i < groupIds.length; i++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(groupIds[i])];
      totalBorrow += groupData.userScaledCrossBorrowed[account].rayMul(groupData.borrowIndex);
    }

    return totalBorrow;
  }

  function erc20GetUserScaledIsolateBorrowInGroup(
    DataTypes.GroupData storage groupData,
    address account
  ) internal view returns (uint256) {
    return groupData.userScaledIsolateBorrowed[account];
  }

  function erc20GetUserIsolateBorrowInGroup(
    DataTypes.GroupData storage groupData,
    address account,
    uint256 index
  ) internal view returns (uint256) {
    return groupData.userScaledIsolateBorrowed[account].rayMul(index);
  }

  /**
   * @dev Increase user borrow balance in the asset, make sure the index already updated.
   */
  function erc20IncreaseCrossBorrow(DataTypes.GroupData storage groupData, address account, uint256 amount) internal {
    uint256 amountScaled = amount.rayDiv(groupData.borrowIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    groupData.totalScaledCrossBorrowed += amountScaled;
    groupData.userScaledCrossBorrowed[account] += amountScaled;
  }

  function erc20IncreaseIsolateBorrow(DataTypes.GroupData storage groupData, address account, uint256 amount) internal {
    uint256 amountScaled = amount.rayDiv(groupData.borrowIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    groupData.totalScaledIsolateBorrowed += amountScaled;
    groupData.userScaledIsolateBorrowed[account] += amountScaled;
  }

  function erc20IncreaseIsolateScaledBorrow(
    DataTypes.GroupData storage groupData,
    address account,
    uint256 amountScaled
  ) internal {
    groupData.totalScaledIsolateBorrowed += amountScaled;
    groupData.userScaledIsolateBorrowed[account] += amountScaled;
  }

  /**
   * @dev Decrease user borrow balance in the asset, make sure the index already updated.
   */
  function erc20DecreaseCrossBorrow(DataTypes.GroupData storage groupData, address account, uint256 amount) internal {
    uint256 amountScaled = amount.rayDiv(groupData.borrowIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    groupData.totalScaledCrossBorrowed -= amountScaled;
    groupData.userScaledCrossBorrowed[account] -= amountScaled;
  }

  function erc20DecreaseIsolateBorrow(DataTypes.GroupData storage groupData, address account, uint256 amount) internal {
    uint256 amountScaled = amount.rayDiv(groupData.borrowIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    groupData.totalScaledIsolateBorrowed -= amountScaled;
    groupData.userScaledIsolateBorrowed[account] -= amountScaled;
  }

  function erc20DecreaseIsolateScaledBorrow(
    DataTypes.GroupData storage groupData,
    address account,
    uint256 amountScaled
  ) internal {
    groupData.totalScaledIsolateBorrowed -= amountScaled;
    groupData.userScaledIsolateBorrowed[account] -= amountScaled;
  }

  function erc20TransferInLiquidity(DataTypes.AssetData storage assetData, address from, uint256 amount) internal {
    address asset = assetData.underlyingAsset;
    uint256 poolSizeBefore = IERC20Upgradeable(asset).balanceOf(address(this));

    assetData.availableLiquidity += amount;

    IERC20Upgradeable(asset).safeTransferFrom(from, address(this), amount);

    uint256 poolSizeAfter = IERC20Upgradeable(asset).balanceOf(address(this));
    require(poolSizeAfter == (poolSizeBefore + amount), Errors.INVALID_TRANSFER_AMOUNT);
  }

  function erc20TransferOutLiquidity(DataTypes.AssetData storage assetData, address to, uint amount) internal {
    address asset = assetData.underlyingAsset;

    require(to != address(0), Errors.INVALID_TO_ADDRESS);

    uint256 poolSizeBefore = IERC20Upgradeable(asset).balanceOf(address(this));

    assetData.availableLiquidity -= amount;

    IERC20Upgradeable(asset).safeTransfer(to, amount);

    uint poolSizeAfter = IERC20Upgradeable(asset).balanceOf(address(this));
    require(poolSizeBefore == (poolSizeAfter + amount), Errors.INVALID_TRANSFER_AMOUNT);
  }

  function erc20TransferBetweenWallets(address asset, address from, address to, uint amount) internal {
    require(to != address(0), Errors.INVALID_TO_ADDRESS);

    uint256 poolSizeBefore = IERC20Upgradeable(asset).balanceOf(to);

    IERC20Upgradeable(asset).safeTransferFrom(from, to, amount);

    uint poolSizeAfter = IERC20Upgradeable(asset).balanceOf(to);
    require(poolSizeBefore == (poolSizeAfter + amount), Errors.INVALID_TRANSFER_AMOUNT);
  }

  function erc20TransferInBidAmount(DataTypes.AssetData storage assetData, address from, uint256 amount) internal {
    address asset = assetData.underlyingAsset;
    uint256 poolSizeBefore = IERC20Upgradeable(asset).balanceOf(address(this));

    assetData.totalBidAmout += amount;

    IERC20Upgradeable(asset).safeTransferFrom(from, address(this), amount);

    uint256 poolSizeAfter = IERC20Upgradeable(asset).balanceOf(address(this));
    require(poolSizeAfter == (poolSizeBefore + amount), Errors.INVALID_TRANSFER_AMOUNT);
  }

  function erc20TransferOutBidAmount(DataTypes.AssetData storage assetData, address to, uint amount) internal {
    address asset = assetData.underlyingAsset;

    require(to != address(0), Errors.INVALID_TO_ADDRESS);

    uint256 poolSizeBefore = IERC20Upgradeable(asset).balanceOf(address(this));

    assetData.totalBidAmout -= amount;

    IERC20Upgradeable(asset).safeTransfer(to, amount);

    uint poolSizeAfter = IERC20Upgradeable(asset).balanceOf(address(this));
    require(poolSizeBefore == (poolSizeAfter + amount), Errors.INVALID_TRANSFER_AMOUNT);
  }

  function erc20TransferOutBidAmountToLiqudity(DataTypes.AssetData storage assetData, uint amount) internal {
    assetData.totalBidAmout -= amount;
    assetData.availableLiquidity += amount;
  }

  //////////////////////////////////////////////////////////////////////////////
  // ERC721 methods
  //////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Get total supply balance in the asset, there's no index for erc721.
   */
  function erc721GetTotalCrossSupply(DataTypes.AssetData storage assetData) internal view returns (uint256) {
    return assetData.totalScaledCrossSupplied;
  }

  function erc721GetTotalIsolateSupply(DataTypes.AssetData storage assetData) internal view returns (uint256) {
    return assetData.totalScaledIsolateSupplied;
  }

  /**
   * @dev Get user supply balance in the asset, there's no index for erc721.
   */
  function erc721GetUserCrossSupply(
    DataTypes.AssetData storage assetData,
    address user
  ) internal view returns (uint256) {
    return assetData.userScaledCrossSupplied[user];
  }

  function erc721GetUserIsolateSupply(
    DataTypes.AssetData storage assetData,
    address user
  ) internal view returns (uint256) {
    return assetData.userScaledIsolateSupplied[user];
  }

  function erc721GetTokenOwnerAndMode(
    DataTypes.AssetData storage assetData,
    uint256 tokenid
  ) internal view returns (address, uint8) {
    DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenid];
    return (tokenData.owner, tokenData.supplyMode);
  }

  function erc721IncreaseCrossSupply(
    DataTypes.AssetData storage assetData,
    address user,
    uint256[] memory tokenIds
  ) internal {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      tokenData.owner = user;
      tokenData.supplyMode = Constants.SUPPLY_MODE_CROSS;
    }

    assetData.totalScaledCrossSupplied += tokenIds.length;
    assetData.userScaledCrossSupplied[user] += tokenIds.length;
  }

  function erc721IncreaseIsolateSupply(
    DataTypes.AssetData storage assetData,
    address user,
    uint256[] memory tokenIds
  ) internal {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      tokenData.owner = user;
      tokenData.supplyMode = Constants.SUPPLY_MODE_ISOLATE;
    }

    assetData.totalScaledIsolateSupplied += tokenIds.length;
    assetData.userScaledIsolateSupplied[user] += tokenIds.length;
  }

  function erc721DecreaseCrossSupply(
    DataTypes.AssetData storage assetData,
    address user,
    uint256[] memory tokenIds
  ) internal {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      require(tokenData.supplyMode == Constants.SUPPLY_MODE_CROSS, Errors.INVALID_SUPPLY_MODE);

      tokenData.owner = address(0);
      tokenData.supplyMode = 0;
    }

    assetData.totalScaledCrossSupplied -= tokenIds.length;
    assetData.userScaledCrossSupplied[user] -= tokenIds.length;
  }

  function erc721DecreaseIsolateSupply(
    DataTypes.AssetData storage assetData,
    address user,
    uint256[] memory tokenIds
  ) internal {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      require(tokenData.supplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);

      tokenData.owner = address(0);
      tokenData.supplyMode = 0;
    }

    assetData.totalScaledIsolateSupplied -= tokenIds.length;
    assetData.userScaledIsolateSupplied[user] -= tokenIds.length;
  }

  /**
   * @dev Transfer user supply balance.
   */
  function erc721TransferCrossSupply(
    DataTypes.AssetData storage assetData,
    address from,
    address to,
    uint256[] memory tokenIds
  ) internal {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      require(tokenData.supplyMode == Constants.SUPPLY_MODE_CROSS, Errors.INVALID_SUPPLY_MODE);

      tokenData.owner = to;
    }

    assetData.userScaledCrossSupplied[from] -= tokenIds.length;
    assetData.userScaledCrossSupplied[to] += tokenIds.length;
  }

  function erc721TransferIsolateSupply(
    DataTypes.AssetData storage assetData,
    address from,
    address to,
    uint256[] memory tokenIds
  ) internal {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      require(tokenData.supplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);

      tokenData.owner = to;
    }

    assetData.userScaledIsolateSupplied[from] -= tokenIds.length;
    assetData.userScaledIsolateSupplied[to] += tokenIds.length;
  }

  function erc721TransferInLiquidity(
    DataTypes.AssetData storage assetData,
    address from,
    uint256[] memory tokenIds
  ) internal {
    address asset = assetData.underlyingAsset;
    uint256 poolSizeBefore = IERC721Upgradeable(asset).balanceOf(address(this));

    assetData.availableLiquidity += tokenIds.length;

    for (uint256 i = 0; i < tokenIds.length; i++) {
      IERC721Upgradeable(asset).safeTransferFrom(from, address(this), tokenIds[i]);
    }

    uint256 poolSizeAfter = IERC721Upgradeable(asset).balanceOf(address(this));

    require(poolSizeAfter == (poolSizeBefore + tokenIds.length), Errors.INVALID_TRANSFER_AMOUNT);
  }

  function erc721TransferOutLiquidity(
    DataTypes.AssetData storage assetData,
    address to,
    uint256[] memory tokenIds
  ) internal {
    address asset = assetData.underlyingAsset;

    require(to != address(0), Errors.INVALID_TO_ADDRESS);

    assetData.availableLiquidity -= tokenIds.length;

    uint256 poolSizeBefore = IERC721Upgradeable(asset).balanceOf(address(this));

    for (uint256 i = 0; i < tokenIds.length; i++) {
      IERC721Upgradeable(asset).safeTransferFrom(address(this), to, tokenIds[i]);
    }

    uint poolSizeAfter = IERC721Upgradeable(asset).balanceOf(address(this));

    require(poolSizeBefore == (poolSizeAfter + tokenIds.length), Errors.INVALID_TRANSFER_AMOUNT);
  }

  //////////////////////////////////////////////////////////////////////////////
  // Misc methods
  //////////////////////////////////////////////////////////////////////////////
  function checkAssetHasEmptyLiquidity(
    DataTypes.PoolData storage /*poolData*/,
    DataTypes.AssetData storage assetData
  ) internal view {
    require(assetData.totalScaledCrossSupplied == 0, Errors.CROSS_SUPPLY_NOT_EMPTY);
    require(assetData.totalScaledIsolateSupplied == 0, Errors.ISOLATE_SUPPLY_NOT_EMPTY);

    uint256[] memory assetGroupIds = assetData.groupList.values();
    for (uint256 gidx = 0; gidx < assetGroupIds.length; gidx++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(assetGroupIds[gidx])];

      checkGroupHasEmptyLiquidity(groupData);
    }
  }

  function checkGroupHasEmptyLiquidity(DataTypes.GroupData storage groupData) internal view {
    require(groupData.totalScaledCrossBorrowed == 0, Errors.CROSS_BORROW_NOT_EMPTY);
    require(groupData.totalScaledIsolateBorrowed == 0, Errors.ISOLATE_BORROW_NOT_EMPTY);
  }
}
