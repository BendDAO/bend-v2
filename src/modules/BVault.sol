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

/// @notice BVault Service Logic
contract BVault is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__BVAULT, moduleGitCommit_) {}

  function depositERC20(uint32 poolId, address asset, uint256 amount) public payable whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      amount = msg.value;
      VaultLogic.wrapNativeTokenInWallet(asset, msgSender, amount);
    } else {
      require(msg.value == 0, Errors.MSG_VALUE_NOT_ZERO);
    }

    SupplyLogic.executeDepositERC20(
      InputTypes.ExecuteDepositERC20Params({msgSender: msgSender, poolId: poolId, asset: asset, amount: amount})
    );
  }

  function withdrawERC20(uint32 poolId, address asset, uint256 amount) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    bool isNative;
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      isNative = true;
      asset = ps.wrappedNativeToken;
    }

    SupplyLogic.executeWithdrawERC20(
      InputTypes.ExecuteWithdrawERC20Params({msgSender: msgSender, poolId: poolId, asset: asset, amount: amount})
    );

    if (isNative) {
      VaultLogic.unwrapNativeTokenInWallet(asset, msgSender, amount);
    }
  }

  function depositERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode
  ) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    SupplyLogic.executeDepositERC721(
      InputTypes.ExecuteDepositERC721Params({
        msgSender: msgSender,
        poolId: poolId,
        asset: asset,
        tokenIds: tokenIds,
        supplyMode: supplyMode
      })
    );
  }

  function batchDepositERC721(
    uint32 poolId,
    address[] calldata assets,
    uint256[][] calldata tokenIdses,
    uint8[] calldata supplyModes
  ) public {
    for (uint i = 0; i < assets.length; i++) {
      depositERC721(poolId, assets[i], tokenIdses[i], supplyModes[i]);
    }
  }

  function withdrawERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode
  ) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    SupplyLogic.executeWithdrawERC721(
      InputTypes.ExecuteWithdrawERC721Params({
        msgSender: msgSender,
        poolId: poolId,
        asset: asset,
        tokenIds: tokenIds,
        supplyMode: supplyMode
      })
    );
  }

  function batchWithdrawERC721(
    uint32 poolId,
    address[] calldata assets,
    uint256[][] calldata tokenIdses,
    uint8[] calldata supplyModes
  ) public {
    for (uint i = 0; i < assets.length; i++) {
      withdrawERC721(poolId, assets[i], tokenIdses[i], supplyModes[i]);
    }
  }

  function setERC721SupplyMode(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode
  ) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    SupplyLogic.executeSetERC721SupplyMode(
      InputTypes.ExecuteSetERC721SupplyModeParams({
        msgSender: msgSender,
        poolId: poolId,
        asset: asset,
        tokenIds: tokenIds,
        supplyMode: supplyMode
      })
    );
  }

  function batchSetERC721SupplyMode(
    uint32 poolId,
    address[] calldata assets,
    uint256[][] calldata tokenIdses,
    uint8[] calldata supplyModes
  ) public {
    for (uint i = 0; i < assets.length; i++) {
      setERC721SupplyMode(poolId, assets[i], tokenIdses[i], supplyModes[i]);
    }
  }

  function collectFeeToTreasury(uint32 poolId, address[] calldata assets) public whenNotPaused nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    PoolLogic.executeCollectFeeToTreasury(msgSender, poolId, assets);
  }
}
