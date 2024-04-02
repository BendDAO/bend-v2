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
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    InterestLogic.updateInterestIndexs(poolData, assetData);

    ValidateLogic.validateDepositERC20(params, poolData, assetData, msg.sender);

    VaultLogic.erc20IncreaseCrossSupply(assetData, msg.sender, params.amount);

    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, msg.sender);

    InterestLogic.updateInterestRates(poolData, assetData, params.amount, 0);

    VaultLogic.erc20TransferInLiquidity(assetData, msg.sender, params.amount);

    emit Events.DepositERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeWithdrawERC20(InputTypes.ExecuteWithdrawERC20Params memory params) public {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    InterestLogic.updateInterestIndexs(poolData, assetData);

    ValidateLogic.validateWithdrawERC20(params, poolData, assetData, msg.sender);

    // withdraw amount can not bigger than supply balance
    uint256 userBalance = VaultLogic.erc20GetUserCrossSupply(assetData, msg.sender, assetData.supplyIndex);
    if (userBalance < params.amount) {
      params.amount = userBalance;
    }

    VaultLogic.erc20DecreaseCrossSupply(assetData, msg.sender, params.amount);

    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, msg.sender);

    InterestLogic.updateInterestRates(poolData, assetData, 0, params.amount);

    VaultLogic.erc20TransferOutLiquidity(assetData, msg.sender, params.amount);

    // check the HF still greater than 1.0
    ValidateLogic.validateHealthFactor(poolData, msg.sender, ps.priceOracle);

    emit Events.WithdrawERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeDepositERC721(InputTypes.ExecuteDepositERC721Params memory params) public {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    ValidateLogic.validateDepositERC721(params, poolData, assetData, msg.sender);

    VaultLogic.erc721TransferInLiquidity(assetData, msg.sender, params.tokenIds);

    if (params.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      VaultLogic.erc721IncreaseCrossSupply(assetData, msg.sender, params.tokenIds);
    } else if (params.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      VaultLogic.erc721IncreaseIsolateSupply(assetData, msg.sender, params.tokenIds);
    }

    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, msg.sender);

    emit Events.DepositERC721(msg.sender, params.poolId, params.asset, params.tokenIds, params.supplyMode);
  }

  function executeWithdrawERC721(InputTypes.ExecuteWithdrawERC721Params memory params) public {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    InterestLogic.updateInterestIndexs(poolData, assetData);

    ValidateLogic.validateWithdrawERC721(params, poolData, assetData, msg.sender);

    if (params.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      VaultLogic.erc721DecreaseCrossSupply(assetData, msg.sender, params.tokenIds);

      VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, msg.sender);

      ValidateLogic.validateHealthFactor(poolData, msg.sender, ps.priceOracle);
    } else if (params.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      for (uint256 i = 0; i < params.tokenIds.length; i++) {
        DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[params.asset][params.tokenIds[i]];
        require(loanData.loanStatus == 0, Errors.ISOLATE_LOAN_EXISTS);
      }

      VaultLogic.erc721DecreaseIsolateSupply(assetData, msg.sender, params.tokenIds);
    }

    VaultLogic.erc721TransferOutLiquidity(assetData, msg.sender, params.tokenIds);

    emit Events.WithdrawERC721(msg.sender, params.poolId, params.asset, params.tokenIds);
  }

  function executeSetERC721SupplyMode(InputTypes.ExecuteSetERC721SupplyModeParams memory params) public {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    ValidateLogic.validatePoolBasic(poolData);
    ValidateLogic.validateAssetBasic(assetData);

    if (params.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      for (uint256 i = 0; i < params.tokenIds.length; i++) {
        DataTypes.ERC721TokenData storage tokenData = VaultLogic.erc721GetTokenData(assetData, params.tokenIds[i]);
        require(tokenData.owner == msg.sender, Errors.INVALID_TOKEN_OWNER);
        require(tokenData.supplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.ASSET_NOT_ISOLATE_MODE);

        DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[params.asset][params.tokenIds[i]];
        require(loanData.loanStatus == 0, Errors.ISOLATE_LOAN_EXISTS);
      }

      VaultLogic.erc721DecreaseIsolateSupply(assetData, msg.sender, params.tokenIds);

      VaultLogic.erc721IncreaseCrossSupply(assetData, msg.sender, params.tokenIds);
    } else if (params.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      for (uint256 i = 0; i < params.tokenIds.length; i++) {
        DataTypes.ERC721TokenData storage tokenData = VaultLogic.erc721GetTokenData(assetData, params.tokenIds[i]);
        require(tokenData.owner == msg.sender, Errors.INVALID_TOKEN_OWNER);
        require(tokenData.supplyMode == Constants.SUPPLY_MODE_CROSS, Errors.ASSET_NOT_CROSS_MODE);

        DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[params.asset][params.tokenIds[i]];
        require(loanData.loanStatus == 0, Errors.ISOLATE_LOAN_EXISTS);
      }

      VaultLogic.erc721DecreaseCrossSupply(assetData, msg.sender, params.tokenIds);

      VaultLogic.erc721IncreaseIsolateSupply(assetData, msg.sender, params.tokenIds);
    } else {
      revert(Errors.INVALID_SUPPLY_MODE);
    }

    VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, msg.sender);

    ValidateLogic.validateHealthFactor(poolData, msg.sender, ps.priceOracle);
  }
}
