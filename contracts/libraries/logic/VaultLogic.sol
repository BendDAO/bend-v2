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

library VaultLogic {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  function erc20Approve(DataTypes.PoolData storage poolData, address owner, address spender, uint256 amount) public {
    poolData.erc20Allowances[owner][spender] = amount;
  }

  function erc20Allowance(
    DataTypes.PoolData storage poolData,
    address owner,
    address spender
  ) public view returns (uint256) {
    return poolData.erc20Allowances[owner][spender];
  }

  function erc721SetApprovalForAll(
    DataTypes.PoolData storage poolData,
    address owner,
    address operator,
    bool approved
  ) public {
    poolData.erc721OperatorApprovals[owner][operator] = approved;
  }

  function erc721IsApprovedForAll(
    DataTypes.PoolData storage poolData,
    address owner,
    address operator
  ) public view returns (bool) {
    return poolData.erc721OperatorApprovals[owner][operator];
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
