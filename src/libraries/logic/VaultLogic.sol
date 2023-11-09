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

  // Account methods
  function accountSetBorrowedAsset(DataTypes.AccountData storage accountData, address asset, bool borrowing) public {
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

  function accountSetSuppliedAsset(
    DataTypes.AccountData storage accountData,
    address asset,
    bool usingAsCollateral
  ) public {
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

  // ERC20 methods
  function erc20GetUserSupply(DataTypes.AssetData storage assetData, address account) public view returns (uint256) {
    uint256 amountScaled = assetData.userCrossSupplied[account];
    return amountScaled.rayMul(assetData.supplyIndex);
  }

  function erc20IncreaseSupply(
    DataTypes.AssetData storage assetData,
    address account,
    uint256 amount
  ) public returns (bool) {
    uint256 amountScaled = amount.rayDiv(assetData.supplyIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    assetData.totalCrossSupplied += amountScaled;
    assetData.userCrossSupplied[account] += amountScaled;

    return (assetData.userCrossSupplied[account] == amountScaled); // first supply
  }

  function erc20DecreaseSupply(
    DataTypes.AssetData storage assetData,
    address account,
    uint256 amount
  ) public returns (bool) {
    uint256 amountScaled = amount.rayDiv(assetData.supplyIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    assetData.totalCrossSupplied -= amountScaled;
    assetData.userCrossSupplied[account] -= amountScaled;

    return (assetData.userCrossSupplied[account] == 0); // full withdraw
  }

  function erc20TransferSupply(DataTypes.AssetData storage assetData, address from, address to, uint256 amount) public {
    uint256 amountScaled = amount.rayDiv(assetData.supplyIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    assetData.userCrossSupplied[from] -= amountScaled;
    assetData.userCrossSupplied[to] += amountScaled;
  }

  function erc20GetUserBorrow(DataTypes.GroupData storage groupData, address account) public view returns (uint256) {
    uint256 amountScaled = groupData.userCrossBorrowed[account];
    return amountScaled.rayMul(groupData.borrowIndex);
  }

  function erc20IncreaseBorrow(
    DataTypes.GroupData storage groupData,
    address account,
    uint256 amount
  ) public returns (bool) {
    uint256 amountScaled = amount.rayDiv(groupData.borrowIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    groupData.totalCrossBorrowed += amountScaled;
    groupData.userCrossBorrowed[account] += amountScaled;

    return (groupData.userCrossBorrowed[account] == amountScaled); // first borrow
  }

  function erc20DecreaseBorrow(
    DataTypes.GroupData storage groupData,
    address account,
    uint256 amount
  ) public returns (bool) {
    uint256 amountScaled = amount.rayDiv(groupData.borrowIndex);
    require(amountScaled != 0, Errors.INVALID_SCALED_AMOUNT);

    groupData.totalCrossBorrowed -= amountScaled;
    groupData.userCrossBorrowed[account] -= amountScaled;

    return (groupData.userCrossBorrowed[account] == 0); // full repay
  }

  function erc20TransferIn(address underlyingAsset, address from, uint256 amount) public {
    uint256 poolSizeBefore = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    IERC20Upgradeable(underlyingAsset).safeTransferFrom(from, address(this), amount);

    uint256 poolSizeAfter = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));
    require(poolSizeAfter == (poolSizeBefore + amount), Errors.INVALID_TRANSFER_AMOUNT);
  }

  function erc20TransferOut(address underlyingAsset, address to, uint amount) public {
    uint256 poolSizeBefore = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    IERC20Upgradeable(underlyingAsset).safeTransfer(to, amount);

    uint poolSizeAfter = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));
    require(poolSizeBefore == (poolSizeAfter + amount), Errors.INVALID_TRANSFER_AMOUNT);
  }

  // ERC721 methods
  function erc721DecreaseSupply(DataTypes.AssetData storage assetData, address user, uint256[] memory tokenIds) public {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      if (tokenData.supplyMode == Constants.SUPPLY_MODE_CROSS) {
        assetData.userCrossSupplied[user] -= 1;
      } else if (tokenData.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
        assetData.userIsolateSupplied[user] -= 1;
      } else {
        revert(Errors.INVALID_SUPPLY_MODE);
      }
      tokenData.owner = address(0);
      tokenData.supplyMode = 0;
    }
  }

  function erc721GetUserCrossSupply(DataTypes.AssetData storage assetData, address user) public view returns (uint256) {
    return assetData.userCrossSupplied[user];
  }

  function erc721TransferSupply(
    DataTypes.AssetData storage assetData,
    address from,
    address to,
    uint256[] memory tokenIds
  ) public {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[tokenIds[i]];
      tokenData.owner = to;
      if (tokenData.supplyMode == Constants.SUPPLY_MODE_CROSS) {
        assetData.userCrossSupplied[from] -= 1;
        assetData.userCrossSupplied[to] += 1;
      } else if (tokenData.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
        assetData.userIsolateSupplied[from] -= 1;
        assetData.userIsolateSupplied[to] += 1;
      } else {
        revert(Errors.INVALID_SUPPLY_MODE);
      }
    }
  }

  function erc721TransferIn(
    address underlyingAsset,
    address from,
    uint256[] memory tokenIds
  ) public returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC721Upgradeable(underlyingAsset).balanceOf(address(this));

    for (uint256 i = 0; i < tokenIds.length; i++) {
      IERC721Upgradeable(underlyingAsset).safeTransferFrom(from, address(this), tokenIds[i]);
    }

    uint256 poolSizeAfter = IERC721Upgradeable(underlyingAsset).balanceOf(address(this));

    require(poolSizeAfter >= poolSizeBefore, Errors.INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeAfter - poolSizeBefore;
    }
  }

  function erc721TransferOut(
    address underlyingAsset,
    address to,
    uint256[] memory tokenIds
  ) public returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC721Upgradeable(underlyingAsset).balanceOf(address(this));

    for (uint256 i = 0; i < tokenIds.length; i++) {
      IERC721Upgradeable(underlyingAsset).safeTransferFrom(address(this), to, tokenIds[i]);
    }

    uint poolSizeAfter = IERC721Upgradeable(underlyingAsset).balanceOf(address(this));

    require(poolSizeBefore >= poolSizeAfter, Errors.INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeBefore - poolSizeAfter;
    }
  }
}
