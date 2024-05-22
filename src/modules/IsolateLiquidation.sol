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

/// @notice Isolate Liquidation Service Logic
contract IsolateLiquidation is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__ISOLATE_LIQUIDATION, moduleGitCommit_) {}

  function isolateAuction(
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

    IsolateLogic.executeIsolateAuction(
      InputTypes.ExecuteIsolateAuctionParams({
        msgSender: msgSender,
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        amounts: amounts
      })
    );
  }

  struct BatchIsolateAuctionLocalVars {
    uint i;
    address msgSender;
    bool isNative;
  }

  function batchIsolateAuction(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[][] calldata nftTokenIdses,
    address[] calldata assets,
    uint256[][] calldata amountses
  ) public payable whenNotPaused nonReentrant {
    BatchIsolateAuctionLocalVars memory vars;
    vars.msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    if (msg.value > 0) {
      vars.isNative = true;
      VaultLogic.wrapNativeTokenInWallet(ps.wrappedNativeToken, vars.msgSender, msg.value);
    }

    for (vars.i = 0; vars.i < nftAssets.length; vars.i++) {
      if (vars.isNative) {
        require(assets[vars.i] == Constants.NATIVE_TOKEN_ADDRESS, Errors.INVALID_NATIVE_TOKEN);
      }

      IsolateLogic.executeIsolateAuction(
        InputTypes.ExecuteIsolateAuctionParams({
          msgSender: vars.msgSender,
          poolId: poolId,
          nftAsset: nftAssets[vars.i],
          nftTokenIds: nftTokenIdses[vars.i],
          asset: vars.isNative ? ps.wrappedNativeToken : assets[vars.i],
          amounts: amountses[vars.i]
        })
      );
    }
  }

  function isolateRedeem(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata /*amounts*/
  ) public payable whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    if (msg.value > 0) {
      require(asset == Constants.NATIVE_TOKEN_ADDRESS, Errors.INVALID_NATIVE_TOKEN);
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msgSender, msg.value);
    }

    IsolateLogic.executeIsolateRedeem(
      InputTypes.ExecuteIsolateRedeemParams({
        msgSender: msgSender,
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset
      })
    );
  }

  struct BatchIsolateRedeemLocalVars {
    uint i;
    address msgSender;
    bool isNative;
  }

  function batchIsolateRedeem(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[][] calldata nftTokenIdses,
    address[] calldata assets,
    uint256[][] calldata /*amountses*/
  ) public payable whenNotPaused nonReentrant {
    BatchIsolateRedeemLocalVars memory vars;
    vars.msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    if (msg.value > 0) {
      vars.isNative = true;
      VaultLogic.wrapNativeTokenInWallet(ps.wrappedNativeToken, vars.msgSender, msg.value);
    }

    for (vars.i = 0; vars.i < nftAssets.length; vars.i++) {
      if (vars.isNative) {
        require(assets[vars.i] == Constants.NATIVE_TOKEN_ADDRESS, Errors.INVALID_NATIVE_TOKEN);
      }

      IsolateLogic.executeIsolateRedeem(
        InputTypes.ExecuteIsolateRedeemParams({
          msgSender: vars.msgSender,
          poolId: poolId,
          nftAsset: nftAssets[vars.i],
          nftTokenIds: nftTokenIdses[vars.i],
          asset: vars.isNative ? ps.wrappedNativeToken : assets[vars.i]
        })
      );
    }
  }

  function isolateLiquidate(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata /*amounts*/,
    bool supplyAsCollateral
  ) public payable whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    if (msg.value > 0) {
      require(asset == Constants.NATIVE_TOKEN_ADDRESS, Errors.INVALID_NATIVE_TOKEN);
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msgSender, msg.value);
    }

    IsolateLogic.executeIsolateLiquidate(
      InputTypes.ExecuteIsolateLiquidateParams({
        msgSender: msgSender,
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }

  struct BatchIsolateLiquidateLocalVars {
    uint i;
    address msgSender;
    bool isNative;
  }

  function batchIsolateLiquidate(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[][] calldata nftTokenIdses,
    address[] calldata assets,
    uint256[][] calldata /*amountses*/,
    bool[] calldata supplyAsCollaterals
  ) public payable whenNotPaused nonReentrant {
    BatchIsolateLiquidateLocalVars memory vars;

    vars.msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    if (msg.value > 0) {
      vars.isNative = true;
      VaultLogic.wrapNativeTokenInWallet(ps.wrappedNativeToken, vars.msgSender, msg.value);
    }

    for (vars.i = 0; vars.i < nftAssets.length; vars.i++) {
      if (vars.isNative) {
        require(assets[vars.i] == Constants.NATIVE_TOKEN_ADDRESS, Errors.INVALID_NATIVE_TOKEN);
      }

      IsolateLogic.executeIsolateLiquidate(
        InputTypes.ExecuteIsolateLiquidateParams({
          msgSender: vars.msgSender,
          poolId: poolId,
          nftAsset: nftAssets[vars.i],
          nftTokenIds: nftTokenIdses[vars.i],
          asset: vars.isNative ? ps.wrappedNativeToken : assets[vars.i],
          supplyAsCollateral: supplyAsCollaterals[vars.i]
        })
      );
    }
  }
}
