// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import {Constants} from './Constants.sol';
import {Errors} from './Errors.sol';
import {InputTypes} from './InputTypes.sol';
import {DataTypes} from './DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

library VaultLogic {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  function transferInForERC20Tokens(
    address underlyingAsset,
    address from,
    uint256 amount
  ) internal returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    IERC20Upgradeable(underlyingAsset).safeTransferFrom(from, address(this), amount);

    uint256 poolSizeAfter = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    require(poolSizeAfter >= poolSizeBefore, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeAfter - poolSizeBefore;
    }
  }

  function transferOutForERC20Tokens(
    address underlyingAsset,
    address to,
    uint amount
  ) internal returns (uint amountTransferred) {
    uint256 poolSizeBefore = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    IERC20Upgradeable(underlyingAsset).safeTransfer(to, amount);
    uint poolSizeAfter = IERC20Upgradeable(underlyingAsset).balanceOf(address(this));

    require(poolSizeBefore >= poolSizeAfter, Errors.CE_INVALID_TRANSFER_AMOUNT);
    unchecked {
      amountTransferred = poolSizeBefore - poolSizeAfter;
    }
  }

  function transferInForERC721Tokens(
    address underlyingAsset,
    address from,
    uint256[] memory tokenIds
  ) internal returns (uint amountTransferred) {
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

  function transferOutForERC721Tokens(
    address underlyingAsset,
    address to,
    uint256[] memory tokenIds
  ) internal returns (uint amountTransferred) {
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
