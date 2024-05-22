// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BaseModule} from '../base/BaseModule.sol';

import {Constants} from '../libraries/helpers/Constants.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {InputTypes} from '../libraries/types/InputTypes.sol';

import {StorageSlot} from '../libraries/logic/StorageSlot.sol';
import {VaultLogic} from '../libraries/logic/VaultLogic.sol';
import {IsolateLogic} from '../libraries/logic/IsolateLogic.sol';
import {QueryLogic} from '../libraries/logic/QueryLogic.sol';

/// @notice Isolate Lending Service Logic
contract IsolateLending is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__ISOLATE_LENDING, moduleGitCommit_) {}

  function isolateBorrow(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    bool isNative;
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      isNative = true;
      asset = ps.wrappedNativeToken;
    }

    uint256 totalBorrowAmount = IsolateLogic.executeIsolateBorrow(
      InputTypes.ExecuteIsolateBorrowParams({
        msgSender: msgSender,
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        amounts: amounts
      })
    );

    if (isNative) {
      VaultLogic.unwrapNativeTokenInWallet(asset, msgSender, totalBorrowAmount);
    }
  }

  struct BatchIsolateBorrowLocalVars {
    uint i;
    address msgSender;
    bool isNative;
    uint256 batchTotalNativeAmount;
  }

  function batchIsolateBorrow(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[][] calldata nftTokenIdses,
    address[] calldata assets,
    uint256[][] calldata amountses
  ) public whenNotPaused nonReentrant {
    BatchIsolateBorrowLocalVars memory vars;
    vars.msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    for (vars.i = 0; vars.i < nftAssets.length; vars.i++) {
      if (assets[vars.i] == Constants.NATIVE_TOKEN_ADDRESS) {
        vars.isNative = true;
      }

      uint256 totalBorrowAmount = IsolateLogic.executeIsolateBorrow(
        InputTypes.ExecuteIsolateBorrowParams({
          msgSender: vars.msgSender,
          poolId: poolId,
          nftAsset: nftAssets[vars.i],
          nftTokenIds: nftTokenIdses[vars.i],
          asset: vars.isNative ? ps.wrappedNativeToken : assets[vars.i],
          amounts: amountses[vars.i]
        })
      );

      if (vars.isNative) {
        vars.batchTotalNativeAmount += totalBorrowAmount;
      }
    }

    if (vars.batchTotalNativeAmount > 0) {
      VaultLogic.unwrapNativeTokenInWallet(ps.wrappedNativeToken, vars.msgSender, vars.batchTotalNativeAmount);
    }
  }

  function isolateRepay(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public payable whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    if (msg.value > 0) {
      require(asset == Constants.NATIVE_TOKEN_ADDRESS, Errors.INVALID_NATIVE_TOKEN);
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msgSender, msg.value);
    }

    IsolateLogic.executeIsolateRepay(
      InputTypes.ExecuteIsolateRepayParams({
        msgSender: msgSender,
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        amounts: amounts
      })
    );
  }

  function batchIsolateRepay(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[][] calldata nftTokenIdses,
    address[] calldata assets,
    uint256[][] calldata amountses
  ) public payable whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    bool isNative;
    if (msg.value == 0) {
      isNative = true;
      VaultLogic.wrapNativeTokenInWallet(ps.wrappedNativeToken, msgSender, msg.value);
    }

    for (uint i = 0; i < nftAssets.length; i++) {
      if (isNative) {
        require(assets[i] == Constants.NATIVE_TOKEN_ADDRESS, Errors.INVALID_NATIVE_TOKEN);
      }

      IsolateLogic.executeIsolateRepay(
        InputTypes.ExecuteIsolateRepayParams({
          msgSender: msgSender,
          poolId: poolId,
          nftAsset: nftAssets[i],
          nftTokenIds: nftTokenIdses[i],
          asset: isNative ? ps.wrappedNativeToken : assets[i],
          amounts: amountses[i]
        })
      );
    }
  }
}
