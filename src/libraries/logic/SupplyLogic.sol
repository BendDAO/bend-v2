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
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);

    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    ValidateLogic.validateDepositERC20(params, poolData, assetData, msg.sender);

    InterestLogic.updateInterestSupplyIndex(assetData);

    VaultLogic.erc20TransferIn(params.asset, msg.sender, params.amount);

    bool isFirstSupply = VaultLogic.erc20IncreaseSupply(assetData, msg.sender, params.amount);
    if (isFirstSupply) {
      DataTypes.AccountData storage accountData = poolData.accountLookup[msg.sender];
      VaultLogic.accountSetSuppliedAsset(accountData, params.asset, true);
    }

    InterestLogic.updateInterestRates(params.asset, assetData, params.amount, 0);

    emit Events.DepositERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeWithdrawERC20(InputTypes.ExecuteWithdrawERC20Params memory params) public {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    ValidateLogic.validateWithdrawERC20(params, poolData, assetData, msg.sender);

    InterestLogic.updateInterestSupplyIndex(assetData);

    // TODO: check if the user has enough collateral to cover debt

    bool isFullWithdraw = VaultLogic.erc20DecreaseSupply(assetData, msg.sender, params.amount);
    if (isFullWithdraw) {
      DataTypes.AccountData storage accountData = poolData.accountLookup[msg.sender];
      VaultLogic.accountSetSuppliedAsset(accountData, params.asset, false);
    }

    VaultLogic.erc20TransferOut(params.asset, params.to, params.amount);

    InterestLogic.updateInterestRates(params.asset, assetData, 0, params.amount);

    ValidateLogic.validateHealthFactor(poolData, msg.sender, cs.priceOracle);

    emit Events.WithdrawERC20(msg.sender, params.poolId, params.asset, params.amount);
  }

  function executeDepositERC721(InputTypes.ExecuteDepositERC721Params memory params) public {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

    ValidateLogic.validateDepositERC721(params, poolData, assetData, msg.sender);

    VaultLogic.erc721TransferIn(params.asset, msg.sender, params.tokenIds);

    for (uint256 i = 0; i < params.tokenIds.length; i++) {
      DataTypes.ERC721TokenData storage tokenData = assetData.erc721TokenData[params.tokenIds[i]];
      tokenData.owner = msg.sender;
      tokenData.supplyMode = uint8(params.supplyMode);
    }

    if (params.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      bool isFirstSupply = (assetData.userCrossSupplied[msg.sender] == 0);

      assetData.totalCrossSupplied += params.tokenIds.length;
      assetData.userCrossSupplied[msg.sender] += params.tokenIds.length;

      if (isFirstSupply) {
        DataTypes.AccountData storage accountData = poolData.accountLookup[msg.sender];
        VaultLogic.accountSetSuppliedAsset(accountData, params.asset, true);
      }
    } else if (params.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      assetData.totalIsolateSupplied += params.tokenIds.length;
      assetData.userIsolateSupplied[msg.sender] += params.tokenIds.length;
    } else {
      revert(Errors.INVALID_SUPPLY_MODE);
    }

    emit Events.DepositERC721(msg.sender, params.poolId, params.asset, params.tokenIds);
  }

  function executeWithdrawERC721(InputTypes.ExecuteWithdrawERC721Params memory params) public {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[params.asset];

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
      bool isFullWithdraw = (assetData.userCrossSupplied[msg.sender] == 0);
      if (isFullWithdraw) {
        DataTypes.AccountData storage accountData = poolData.accountLookup[msg.sender];
        VaultLogic.accountSetSuppliedAsset(accountData, params.asset, false);
      }

      // TODO: check if the user has enough collateral to cover debt
      ValidateLogic.validateHealthFactor(poolData, msg.sender, cs.priceOracle);
    }

    VaultLogic.erc721TransferOut(params.asset, params.to, params.tokenIds);

    emit Events.WithdrawERC721(msg.sender, params.poolId, params.asset, params.tokenIds);
  }
}
