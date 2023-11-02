// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';
import {WadRayMath} from '../math/WadRayMath.sol';

library VaultLogic {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using WadRayMath for uint256;

  // Account methods
  function accountAddAsset(DataTypes.AccountData storage accountData, address asset, bool isForSupplied) public {
    address[] storage assetsInStorage;

    if (isForSupplied) {
      assetsInStorage = accountData.suppliedAssets;
    } else {
      assetsInStorage = accountData.borrowedAssets;
    }

    if (assetsInStorage.length == 0) {
      assetsInStorage.push(asset);
    } else {
      bool isExist = false;
      for (uint256 i = 0; i < assetsInStorage.length; i++) {
        if (assetsInStorage[i] == asset) {
          isExist = true;
          break;
        }
      }
      if (!isExist) {
        assetsInStorage.push(asset);
      }
    }
  }

  function accountRemoveAsset(DataTypes.AccountData storage accountData, address asset, bool isForSupplied) public {
    address[] storage assetsInStorage;

    if (isForSupplied) {
      assetsInStorage = accountData.suppliedAssets;
    } else {
      assetsInStorage = accountData.borrowedAssets;
    }

    if (assetsInStorage.length == 0) {
      return;
    }

    for (uint256 i = 0; i < assetsInStorage.length; i++) {
      if (assetsInStorage[i] == asset) {
        assetsInStorage[i] = assetsInStorage[assetsInStorage.length - 1];
        assetsInStorage.pop();
        break;
      }
    }
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
    require(amountScaled != 0, Errors.CE_INVALID_SCALED_AMOUNT);

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
    require(amountScaled != 0, Errors.CE_INVALID_SCALED_AMOUNT);

    assetData.totalCrossSupplied -= amountScaled;
    assetData.userCrossSupplied[account] -= amountScaled;

    return (assetData.userCrossSupplied[account] == 0); // full withdraw
  }

  function erc20TransferSupply(DataTypes.AssetData storage assetData, address from, address to, uint256 amount) public {
    uint256 amountScaled = amount.rayDiv(assetData.supplyIndex);
    require(amountScaled != 0, Errors.CE_INVALID_SCALED_AMOUNT);

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
    require(amountScaled != 0, Errors.CE_INVALID_SCALED_AMOUNT);

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
    require(amountScaled != 0, Errors.CE_INVALID_SCALED_AMOUNT);

    groupData.totalCrossBorrowed -= amountScaled;
    groupData.userCrossBorrowed[account] -= amountScaled;

    return (groupData.userCrossBorrowed[account] == 0); // full repay
  }

  function erc20TransferIn(
    address underlyingAsset,
    address from,
    uint256 amount
  ) public returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    IERC20Upgradeable(underlyingAsset).safeTransferFrom(from, address(this), amount);

    uint256 poolSizeAfter = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    require(poolSizeAfter >= poolSizeBefore, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeAfter - poolSizeBefore;
    }
  }

  function erc20TransferOut(address underlyingAsset, address to, uint amount) public returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    IERC20Upgradeable(underlyingAsset).safeTransfer(to, amount);
    uint poolSizeAfter = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    require(poolSizeBefore >= poolSizeAfter, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeBefore - poolSizeAfter;
    }
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
        revert(Errors.CE_INVALID_SUPPLY_MODE);
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
        revert(Errors.CE_INVALID_SUPPLY_MODE);
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

    require(poolSizeAfter >= poolSizeBefore, Errors.CE_INVALID_TRANSFER_AMOUNT);
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

    require(poolSizeBefore >= poolSizeAfter, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeBefore - poolSizeAfter;
    }
  }
}
