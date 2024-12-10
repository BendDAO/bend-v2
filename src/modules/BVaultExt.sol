// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BaseModule} from '../base/BaseModule.sol';

import {Constants} from '../libraries/helpers/Constants.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';
import {InputTypes} from '../libraries/types/InputTypes.sol';

import {StorageSlot} from '../libraries/logic/StorageSlot.sol';
import {VaultLogic} from '../libraries/logic/VaultLogic.sol';
import {SupplyLogic} from '../libraries/logic/SupplyLogic.sol';
import {PoolLogic} from '../libraries/logic/PoolLogic.sol';

/// @notice BVaultExt Service Logic
contract BVaultExt is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__BVAULT_EXT, moduleGitCommit_) {}

  function depositIsolateERC20(
    uint32 poolId,
    address asset,
    uint256 amount,
    address onBehalf
  ) public payable whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      amount = msg.value;
      VaultLogic.wrapNativeTokenInWallet(asset, msgSender, msg.value);
    } else {
      require(msg.value == 0, Errors.MSG_VALUE_NOT_ZERO);
    }

    SupplyLogic.executeDepositIsolateERC20(
      InputTypes.ExecuteDepositERC20Params({
        msgSender: msgSender,
        poolId: poolId,
        asset: asset,
        amount: amount,
        supplyMode: Constants.SUPPLY_MODE_ISOLATE,
        onBehalf: onBehalf
      })
    );
  }

  function withdrawIsolateERC20(
    uint32 poolId,
    address asset,
    uint256 amount,
    address onBehalf,
    address receiver
  ) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    bool isNative;
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      isNative = true;
      asset = ps.wrappedNativeToken;
    }

    SupplyLogic.executeWithdrawIsolateERC20(
      InputTypes.ExecuteWithdrawERC20Params({
        msgSender: msgSender,
        poolId: poolId,
        asset: asset,
        amount: amount,
        supplyMode: Constants.SUPPLY_MODE_ISOLATE,
        onBehalf: onBehalf,
        receiver: receiver
      })
    );

    if (isNative) {
      require(msgSender == receiver, Errors.SENDER_RECEIVER_NOT_SAME);
      VaultLogic.unwrapNativeTokenInWallet(asset, receiver, amount);
    }
  }

  function setERC20SupplyMode(
    uint32 poolId,
    address asset,
    uint256 amount,
    uint8 supplyMode,
    address onBehalf
  ) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    SupplyLogic.executeSetERC20SupplyMode(
      InputTypes.ExecuteSetERC20SupplyModeParams({
        msgSender: msgSender,
        poolId: poolId,
        asset: asset,
        amount: amount,
        supplyMode: supplyMode,
        onBehalf: onBehalf
      })
    );
  }
}
