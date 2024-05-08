// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';
import {WadRayMath} from '../math/WadRayMath.sol';

import {IAddressProvider} from '../../interfaces/IAddressProvider.sol';
import {IACLManager} from '../../interfaces/IACLManager.sol';
import {IWETH} from '../../interfaces/IWETH.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';
import {ValidateLogic} from './ValidateLogic.sol';

library PoolLogic {
  using WadRayMath for uint256;

  // check caller's permission
  function checkCallerIsPoolAdmin(DataTypes.PoolStorage storage ps, address msgSender) internal view {
    IACLManager aclManager = IACLManager(IAddressProvider(ps.addressProvider).getACLManager());
    require(aclManager.isPoolAdmin(msgSender), Errors.CALLER_NOT_POOL_ADMIN);
  }

  function checkCallerIsEmergencyAdmin(DataTypes.PoolStorage storage ps, address msgSender) internal view {
    IACLManager aclManager = IACLManager(IAddressProvider(ps.addressProvider).getACLManager());
    require(aclManager.isEmergencyAdmin(msgSender), Errors.CALLER_NOT_EMERGENCY_ADMIN);
  }

  function executeCollectFeeToTreasury(address msgSender, uint32 poolId, address[] calldata assets) internal {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    checkCallerIsPoolAdmin(ps, msgSender);

    address treasuryAddress = IAddressProvider(ps.addressProvider).getTreasury();
    require(treasuryAddress != address(0), Errors.TREASURY_CANNOT_BE_ZERO);

    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    ValidateLogic.validatePoolBasic(poolData);

    for (uint256 i = 0; i < assets.length; i++) {
      address assetAddress = assets[i];
      DataTypes.AssetData storage assetData = poolData.assetLookup[assetAddress];
      ValidateLogic.validateAssetBasic(assetData);

      uint256 accruedFee = assetData.accruedFee;
      if (accruedFee == 0) {
        continue;
      }

      assetData.accruedFee = 0;

      InterestLogic.updateInterestIndexs(poolData, assetData);
      uint256 normalizedIncome = InterestLogic.getNormalizedSupplyIncome(assetData);

      uint256 amountToCollect = accruedFee.rayMul(normalizedIncome);

      VaultLogic.erc20IncreaseCrossSupply(assetData, treasuryAddress, amountToCollect);
      VaultLogic.accountCheckAndSetSuppliedAsset(poolData, assetData, treasuryAddress);

      emit Events.CollectFeeToTreasury(poolId, assetAddress, amountToCollect, normalizedIncome);
    }
  }
}
