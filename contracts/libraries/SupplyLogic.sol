// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from './Constants.sol';
import {Errors} from './Errors.sol';
import {InputTypes} from './InputTypes.sol';
import {DataTypes} from './DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {VaultLogic} from './VaultLogic.sol';

library SupplyLogic {
  function executeDepositERC20(InputTypes.ExecuteDepositERC20Params memory params) external {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[params.poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[params.asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    VaultLogic.transferInForERC20Tokens(params.asset, msg.sender, params.amount);

    assetStorage.totalCrossSupplied += params.amount;
    assetStorage.userCrossSupplied[params.onBehalfOf] += params.amount;
  }

  function executeWithdrawERC20(InputTypes.ExecuteWithdrawERC20Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[params.poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[params.asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC20, Errors.PE_ASSET_NOT_EXISTS);

    assetStorage.totalCrossSupplied -= params.amount;
    assetStorage.userCrossSupplied[msg.sender] -= params.amount;

    VaultLogic.transferOutForERC20Tokens(params.asset, params.to, params.amount);

    // TODO: check if the user has enough collateral to cover debt
  }

  function executeDepositERC721(InputTypes.ExecuteDepositERC721Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[params.poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[params.asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC721, Errors.PE_ASSET_NOT_EXISTS);

    VaultLogic.transferInForERC721Tokens(params.asset, msg.sender, params.tokenIds);

    for (uint256 i = 0; i < params.tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetStorage.erc721TokenData[params.tokenIds[i]];
      tokenData.owner = params.onBehalfOf;
      tokenData.supplyMode = uint8(params.supplyMode);
    }

    if (params.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      assetStorage.totalCrossSupplied += params.tokenIds.length;
      assetStorage.userCrossSupplied[params.onBehalfOf] += params.tokenIds.length;
    } else if (params.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      assetStorage.totalIsolateSupplied += params.tokenIds.length;
      assetStorage.userIsolateSupplied[params.onBehalfOf] += params.tokenIds.length;
    } else {
      revert(Errors.CE_INVALID_SUPPLY_MODE);
    }
  }

  function executeWithdrawERC721(InputTypes.ExecuteWithdrawERC721Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.Pool storage pool = ps.poolLookup[params.poolId];
    DataTypes.Asset storage assetStorage = pool.assetLookup[params.asset];
    require(assetStorage.assetType == Constants.ASSET_TYPE_ERC721, Errors.PE_ASSET_NOT_EXISTS);

    for (uint256 i = 0; i < params.tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetStorage.erc721TokenData[params.tokenIds[i]];
      require(tokenData.owner == msg.sender, Errors.CE_INVALID_CALLER);
      tokenData.owner = address(0);
      tokenData.supplyMode = 0;
    }

    VaultLogic.transferOutForERC721Tokens(params.asset, params.to, params.tokenIds);

    // TODO: check if the user has enough collateral to cover debt
  }
}
