// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IPriceOracleGetter} from '../../interfaces/IPriceOracleGetter.sol';

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';

import {PercentageMath} from '../math/PercentageMath.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {ResultTypes} from '../types/ResultTypes.sol';
import {InputTypes} from '../types/InputTypes.sol';

import {GenericLogic} from './GenericLogic.sol';
import {VaultLogic} from './VaultLogic.sol';

library ValidateLogic {
  using PercentageMath for uint256;

  function validatePoolBasic(DataTypes.PoolData storage poolData) internal view {
    require(poolData.poolId != 0, Errors.POOL_NOT_EXISTS);
  }

  function validateAssetBasic(DataTypes.AssetData storage assetData) internal view {
    require(assetData.assetType != 0, Errors.ASSET_NOT_EXISTS);
    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      require(assetData.underlyingDecimals > 0, Errors.INVALID_ASSET_DECIMALS);
    } else {
      require(assetData.underlyingDecimals == 0, Errors.INVALID_ASSET_DECIMALS);
    }
    require(assetData.riskGroupId != 0, Errors.INVALID_GROUP_ID);

    require(assetData.isActive, Errors.ASSET_NOT_ACTIVE);
    require(!assetData.isPaused, Errors.ASSET_IS_PAUSED);
  }

  function validateGroupBasic(DataTypes.GroupData storage groupData) internal view {
    require(groupData.interestRateModelAddress != address(0), Errors.INVALID_IRM_ADDRESS);
  }

  function validateDepositERC20(
    InputTypes.ExecuteDepositERC20Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address //user
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(assetData);

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);
    require(inputParams.amount > 0, Errors.INVALID_AMOUNT);

    require(!assetData.isFrozen, Errors.ASSET_IS_FROZEN);
  }

  function validateWithdrawERC20(
    InputTypes.ExecuteWithdrawERC20Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address //user
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(assetData);

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);
    require(inputParams.amount > 0, Errors.INVALID_AMOUNT);
  }

  function validateDepositERC721(
    InputTypes.ExecuteDepositERC721Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address //user
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(assetData);

    require(assetData.assetType == Constants.ASSET_TYPE_ERC721, Errors.ASSET_TYPE_NOT_ERC721);
    require(inputParams.tokenIds.length > 0, Errors.INVALID_ID_LIST);
    require(
      inputParams.supplyMode == Constants.SUPPLY_MODE_CROSS || inputParams.supplyMode == Constants.SUPPLY_MODE_ISOLATE,
      Errors.INVALID_SUPPLY_MODE
    );

    require(!assetData.isFrozen, Errors.ASSET_IS_FROZEN);
  }

  function validateWithdrawERC721(
    InputTypes.ExecuteWithdrawERC721Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    address //user
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(assetData);

    require(assetData.assetType == Constants.ASSET_TYPE_ERC721, Errors.ASSET_TYPE_NOT_ERC721);
    require(inputParams.tokenIds.length > 0, Errors.INVALID_ID_LIST);
  }

  struct ValidateBorrowERC20Vars {
    uint256 amountInBaseCurrency;
    uint256 collateralNeededInBaseCurrency;
  }

  function validateBorrowERC20(
    InputTypes.ExecuteBorrowERC20Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    DataTypes.GroupData storage groupData,
    address user,
    address priceOracle
  ) internal view {
    ValidateBorrowERC20Vars memory vars;

    validatePoolBasic(poolData);
    validateAssetBasic(assetData);
    validateGroupBasic(groupData);

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);
    require(inputParams.amount > 0, Errors.INVALID_AMOUNT);
    require(inputParams.to != address(0), Errors.INVALID_TO_ADDRESS);

    require(!assetData.isFrozen, Errors.ASSET_IS_FROZEN);
    require(assetData.isBorrowingEnabled, Errors.ASSET_IS_BORROW_DISABLED);

    ResultTypes.UserAccountResult memory userAccountResult = GenericLogic.calculateUserAccountDataForBorrow(
      poolData,
      user,
      inputParams.group,
      priceOracle
    );

    require(userAccountResult.groupCollateralInBaseCurrency != 0, Errors.COLLATERAL_BALANCE_IS_ZERO);
    require(userAccountResult.groupAvgLtv != 0, Errors.LTV_VALIDATION_FAILED);

    require(
      userAccountResult.healthFactor >= Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
    );

    vars.amountInBaseCurrency = IPriceOracleGetter(priceOracle).getAssetPrice(inputParams.asset) * inputParams.amount;
    vars.amountInBaseCurrency = vars.amountInBaseCurrency / (10 ** assetData.underlyingDecimals);

    //add the current already borrowed amount to the amount requested to calculate the total collateral needed.
    vars.collateralNeededInBaseCurrency = (userAccountResult.groupDebtInBaseCurrency + vars.amountInBaseCurrency)
      .percentDiv(userAccountResult.groupAvgLtv); //LTV is calculated in percentage

    require(
      vars.collateralNeededInBaseCurrency <= userAccountResult.groupCollateralInBaseCurrency,
      Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW
    );
  }

  function validateRepayERC20(
    InputTypes.ExecuteRepayERC20Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage assetData,
    DataTypes.GroupData storage groupData
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(assetData);
    validateGroupBasic(groupData);

    require(assetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);
    require(inputParams.amount > 0, Errors.INVALID_AMOUNT);
  }

  function validateLiquidateERC20(
    InputTypes.ExecuteLiquidateERC20Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage collateralAssetData,
    DataTypes.AssetData storage debtAssetData,
    DataTypes.GroupData storage debtGroupData
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(collateralAssetData);
    validateAssetBasic(debtAssetData);
    validateGroupBasic(debtGroupData);

    require(collateralAssetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);
    require(debtAssetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    require(inputParams.debtToCover > 0, Errors.INVALID_DEBT_AMOUNT);
  }

  function validateLiquidateERC721(
    InputTypes.ExecuteLiquidateERC721Params memory inputParams,
    DataTypes.PoolData storage poolData,
    DataTypes.AssetData storage collateralAssetData,
    DataTypes.AssetData storage debtAssetData,
    DataTypes.GroupData storage debtGroupData
  ) internal view {
    validatePoolBasic(poolData);
    validateAssetBasic(collateralAssetData);
    validateAssetBasic(debtAssetData);
    validateGroupBasic(debtGroupData);

    require(collateralAssetData.assetType == Constants.ASSET_TYPE_ERC721, Errors.ASSET_TYPE_NOT_ERC721);
    require(debtAssetData.assetType == Constants.ASSET_TYPE_ERC20, Errors.ASSET_TYPE_NOT_ERC20);

    require(inputParams.collateralTokenIds.length > 0, Errors.INVALID_ID_LIST);

    for (uint256 i = 0; i < inputParams.collateralTokenIds.length; i++) {
      (address owner, uint8 supplyMode) = VaultLogic.erc721GetTokenOwnerAndMode(
        collateralAssetData,
        inputParams.collateralTokenIds[i]
      );
      require(owner == inputParams.user, Errors.INVALID_TOKEN_OWNER);
      require(supplyMode == Constants.SUPPLY_MODE_CROSS, Errors.ASSET_NOT_CROSS_MODE);
    }
  }

  function validateHealthFactor(
    DataTypes.PoolData storage poolData,
    address userAccount,
    address oracle
  ) internal view returns (uint256, bool) {
    ResultTypes.UserAccountResult memory userAccountResult = GenericLogic.calculateUserAccountDataForHeathFactor(
      poolData,
      userAccount,
      oracle
    );

    require(
      userAccountResult.healthFactor >= Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
    );

    return (userAccountResult.healthFactor, userAccountResult.hasZeroLtvCollateral);
  }
}
