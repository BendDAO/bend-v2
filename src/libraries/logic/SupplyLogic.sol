// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';
import {ValidateLogic} from './ValidateLogic.sol';

library SupplyLogic {
  function executeDepositERC20(InputTypes.ExecuteDepositERC20Params memory params) external {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    InterestLogic.updateInterestSupplyIndex(assetData);

    ValidateLogic.validateDepositERC20(params, poolData, assetData, msg.sender);

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    VaultLogic.erc20IncreaseSupply(assetData, msg.sender, params.amount);

    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, params.asset, msg.sender);

    InterestLogic.updateInterestRates(poolData, params.asset, assetData, params.amount, 0);

    emit Events.DepositERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeWithdrawERC20(InputTypes.ExecuteWithdrawERC20Params memory params) public {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    InterestLogic.updateInterestSupplyIndex(assetData);

    ValidateLogic.validateWithdrawERC20(params, poolData, assetData, msg.sender);

    uint256 userBalance = VaultLogic.erc20GetUserSupply(assetData, msg.sender);
    if (userBalance < params.amount) {
      params.amount = userBalance;
    }

    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, params.asset, msg.sender);

    VaultLogic.erc20TransferOut(params.asset, params.to, params.amount);

    InterestLogic.updateInterestRates(poolData, params.asset, assetData, 0, params.amount);

    ValidateLogic.validateHealthFactor(poolData, msg.sender, cs.priceOracle);

    emit Events.WithdrawERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeDepositERC721(InputTypes.ExecuteDepositERC721Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    ValidateLogic.validateDepositERC721(params, poolData, assetData, msg.sender);

    VaultLogic.erc721TransferIn(params.asset, msg.sender, params.tokenIds);

    VaultLogic.erc721IncreaseSupply(assetData, msg.sender, params.tokenIds, params.supplyMode);

    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, params.asset, msg.sender);

    emit Events.DepositERC721(msg.sender, params.poolId, params.asset, params.tokenIds);
  }

  function executeWithdrawERC721(InputTypes.ExecuteWithdrawERC721Params memory params) public {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    InterestLogic.updateInterestSupplyIndex(assetData);

    ValidateLogic.validateWithdrawERC721(params, poolData, assetData, msg.sender);

    bool isCrossWithdraw = false;

    for (uint256 i = 0; i < params.tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[params.tokenIds[i]];
      require(tokenData.owner == msg.sender, Errors.INVALID_CALLER);

      if (tokenData.supplyMode == Constants.SUPPLY_MODE_CROSS) {
        isCrossWithdraw = true;

        assetData.totalCrossSupplied -= params.tokenIds.length;
        assetData.userCrossSupplied[msg.sender] -= params.tokenIds.length;
      } else if (tokenData.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
        assetData.totalIsolateSupplied -= params.tokenIds.length;
        assetData.userIsolateSupplied[msg.sender] -= params.tokenIds.length;

        // TODO: check if the nft has debt in isolate mode
      }

      tokenData.owner = address(0);
      tokenData.supplyMode = 0;
    }

    if (isCrossWithdraw) {
      VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, params.asset, msg.sender);

      ValidateLogic.validateHealthFactor(poolData, msg.sender, cs.priceOracle);
    } else {
      // TODO: check isolate debt hf
    }

    VaultLogic.erc721TransferOut(params.asset, params.to, params.tokenIds);

    emit Events.WithdrawERC721(msg.sender, params.poolId, params.asset, params.tokenIds);
  }
}
