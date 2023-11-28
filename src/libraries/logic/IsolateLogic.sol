// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Constants} from '../helpers/Constants.sol';
import {Errors} from '../helpers/Errors.sol';
import {Events} from '../helpers/Events.sol';

import {WadRayMath} from '../math/WadRayMath.sol';
import {InputTypes} from '../types/InputTypes.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {StorageSlot} from './StorageSlot.sol';

import {VaultLogic} from './VaultLogic.sol';
import {InterestLogic} from './InterestLogic.sol';
import {ValidateLogic} from './ValidateLogic.sol';

library IsolateLogic {
  using WadRayMath for uint256;

  struct ExecuteIsolateBorrowERC20LocalVars {
    uint256 totalBorrowAmount;
    uint256 nidx;
    uint256 amountScaled;
  }

  function executeIsolateBorrowERC20(InputTypes.ExecuteIsolateBorrowERC20Params memory params) public {
    ExecuteIsolateBorrowERC20LocalVars memory vars;

    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[params.asset];
    DataTypes.AssetData storage nftAssetData = poolData.assetLookup[params.nftAsset];

    // check the basic params
    ValidateLogic.validateIsolateBorrowERC20Basic(params, poolData, debtAssetData, nftAssetData, msg.sender);

    // update debt state
    vars.totalBorrowAmount;
    for (vars.nidx = 0; vars.nidx < params.nftTokenIds.length; vars.nidx++) {
      DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[nftAssetData.classGroup];
      DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[params.nftAsset][params.nftTokenIds[vars.nidx]];

      InterestLogic.updateInterestBorrowIndex(debtAssetData, debtGroupData);

      ValidateLogic.validateIsolateBorrowERC20Loan(
        params,
        vars.nidx,
        poolData,
        debtAssetData,
        debtGroupData,
        nftAssetData,
        loanData,
        cs.priceOracle
      );

      vars.amountScaled = params.amounts[vars.nidx].rayDiv(debtGroupData.borrowIndex);

      if (loanData.loanStatus == 0) {
        loanData.reserveAsset = params.asset;
        loanData.reserveGroup = nftAssetData.classGroup;
        loanData.scaledAmount = vars.amountScaled;
        loanData.loanStatus = Constants.LOAN_STATUS_ACTIVE;
      } else {
        loanData.scaledAmount += vars.amountScaled;
      }

      VaultLogic.erc20IncreaseIsolateScaledBorrow(debtGroupData, msg.sender, vars.amountScaled);

      vars.totalBorrowAmount += params.amounts[vars.nidx];
    }

    InterestLogic.updateInterestRates(poolData, debtAssetData, 0, vars.totalBorrowAmount);

    // transfer underlying asset to borrower
    VaultLogic.erc20TransferOut(params.asset, msg.sender, vars.totalBorrowAmount);

    emit Events.IsolateBorrowERC20(
      msg.sender,
      params.poolId,
      params.nftAsset,
      params.nftTokenIds,
      params.asset,
      params.amounts
    );
  }

  struct ExecuteIsolateRepayERC20LocalVars {
    uint256 totalRepayAmount;
    uint256 nidx;
    uint256 amountScaled;
    bool isFullRepay;
  }

  function executeIsolateRepayERC20(InputTypes.ExecuteIsolateRepayERC20Params memory params) public {
    ExecuteIsolateRepayERC20LocalVars memory vars;

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();

    DataTypes.PoolData storage poolData = ps.poolLookup[params.poolId];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[params.asset];
    DataTypes.AssetData storage nftAssetData = poolData.assetLookup[params.nftAsset];

    // do some basic checks, e.g. params
    ValidateLogic.validateIsolateRepayERC20Basic(params, poolData, debtAssetData, nftAssetData);

    for (uint256 nidx = 0; nidx < params.nftTokenIds.length; nidx++) {
      DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[params.nftAsset][params.nftTokenIds[vars.nidx]];
      DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[loanData.reserveGroup];

      InterestLogic.updateInterestBorrowIndex(debtAssetData, debtGroupData);

      ValidateLogic.validateIsolateRepayERC20Loan(params, debtGroupData, loanData);

      vars.isFullRepay = false;
      vars.amountScaled = params.amounts[vars.nidx].rayDiv(debtGroupData.borrowIndex);
      if (vars.amountScaled > loanData.scaledAmount) {
        vars.amountScaled = loanData.scaledAmount;
        params.amounts[vars.nidx] = vars.amountScaled.rayMul(debtGroupData.borrowIndex);
        vars.isFullRepay = true;
      }

      if (vars.isFullRepay) {
        delete poolData.loanLookup[params.nftAsset][params.nftTokenIds[vars.nidx]];
      } else {
        loanData.scaledAmount -= vars.amountScaled;
      }

      VaultLogic.erc20DecreaseIsolateScaledBorrow(debtGroupData, msg.sender, vars.amountScaled);

      InterestLogic.updateInterestRates(poolData, debtAssetData, params.amounts[vars.nidx], 0);

      vars.totalRepayAmount += params.amounts[vars.nidx];
    }

    // transfer underlying asset from borrower to pool
    VaultLogic.erc20TransferIn(params.asset, msg.sender, vars.totalRepayAmount);

    emit Events.IsolateRepayERC20(
      msg.sender,
      params.poolId,
      params.nftAsset,
      params.nftTokenIds,
      params.asset,
      params.amounts
    );
  }
}
