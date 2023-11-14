// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';

import {DataTypes} from '../types/DataTypes.sol';
import {InputTypes} from '../types/InputTypes.sol';

library ValidateLogic {
  function validatePoolBasic(DataTypes.PoolData storage poolData) internal view {
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);
  }

  function validateAssetBasic(DataTypes.AssetData storage assetData) internal view {
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);
    require(assetData.underlyingDecimals > 0, Errors.INVALID_ASSET_DECIMALS);
    require(assetData.riskGroupId != 0, Errors.INVALID_GROUP_ID);
  }

  function validateGroupBasic(DataTypes.GroupData storage groupData) internal view {
    require(groupData.interestRateModelAddress != address(0), Errors.INVALID_IRM_ADDRESS);
  }

  function validateBorrowERC20(
    InputTypes.ExecuteBorrowERC20Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    DataTypes.GroupData storage groupData
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(assetData);
    validateGroupBasic(groupData);

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);
    require(inputParams.amount > 0, Errors.INVALID_AMOUNT);
    require(inputParams.to != address(0), Errors.INVALID_TO_ADDRESS);
  }
}
