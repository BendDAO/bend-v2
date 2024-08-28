// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {BaseModule} from 'src/base/BaseModule.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {DataTypes} from '../libraries/types/DataTypes.sol';

import {StorageSlot} from 'src/libraries/logic/StorageSlot.sol';
import {ConfigureLogic} from 'src/libraries/logic/ConfigureLogic.sol';
import {PoolLogic} from 'src/libraries/logic/PoolLogic.sol';

/// @notice Configrator Service Logic
contract Configurator is BaseModule {
  constructor(bytes32 moduleGitCommit_) BaseModule(Constants.MODULEID__CONFIGURATOR, moduleGitCommit_) {}

  function addAssetERC20(uint32 poolId, address asset) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeAddAssetERC20(msgSender, poolId, asset);
  }

  function removeAssetERC20(uint32 poolId, address asset) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeRemoveAssetERC20(msgSender, poolId, asset);
  }

  function addAssetERC721(uint32 poolId, address asset) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeAddAssetERC721(msgSender, poolId, asset);
  }

  function removeAssetERC721(uint32 poolId, address asset) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeRemoveAssetERC721(msgSender, poolId, asset);
  }

  function addAssetGroup(uint32 poolId, address asset, uint8 groupId, address rateModel_) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeAddAssetGroup(msgSender, poolId, asset, groupId, rateModel_);
  }

  function removeAssetGroup(uint32 poolId, address asset, uint8 groupId) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeRemoveAssetGroup(msgSender, poolId, asset, groupId);
  }

  function setAssetActive(uint32 poolId, address asset, bool isActive) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetActive(msgSender, poolId, asset, isActive);
  }

  function setAssetFrozen(uint32 poolId, address asset, bool isFrozen) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetFrozen(msgSender, poolId, asset, isFrozen);
  }

  function setAssetPause(uint32 poolId, address asset, bool isPause) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetPause(msgSender, poolId, asset, isPause);
  }

  function setAssetBorrowing(uint32 poolId, address asset, bool isEnable) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetBorrowing(msgSender, poolId, asset, isEnable);
  }

  function setAssetFlashLoan(uint32 poolId, address asset, bool isEnable) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetFlashLoan(msgSender, poolId, asset, isEnable);
  }

  function setAssetSupplyCap(uint32 poolId, address asset, uint256 newCap) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetSupplyCap(msgSender, poolId, asset, newCap);
  }

  function setAssetBorrowCap(uint32 poolId, address asset, uint256 newCap) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetBorrowCap(msgSender, poolId, asset, newCap);
  }

  function setAssetClassGroup(uint32 poolId, address asset, uint8 classGroup) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetClassGroup(msgSender, poolId, asset, classGroup);
  }

  function setAssetCollateralParams(
    uint32 poolId,
    address asset,
    uint16 collateralFactor,
    uint16 liquidationThreshold,
    uint16 liquidationBonus
  ) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetCollateralParams(
      msgSender,
      poolId,
      asset,
      collateralFactor,
      liquidationThreshold,
      liquidationBonus
    );
  }

  function setAssetAuctionParams(
    uint32 poolId,
    address asset,
    uint16 redeemThreshold,
    uint16 bidFineFactor,
    uint16 minBidFineFactor,
    uint40 auctionDuration
  ) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetAuctionParams(
      msgSender,
      poolId,
      asset,
      redeemThreshold,
      bidFineFactor,
      minBidFineFactor,
      auctionDuration
    );
  }

  function setAssetProtocolFee(uint32 poolId, address asset, uint16 feeFactor) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetProtocolFee(msgSender, poolId, asset, feeFactor);
  }

  function setAssetLendingRate(uint32 poolId, address asset, uint8 groupId, address rateModel_) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetLendingRate(msgSender, poolId, asset, groupId, rateModel_);
  }

  function setAssetYieldEnable(uint32 poolId, address asset, bool isEnable) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetYieldEnable(msgSender, poolId, asset, isEnable);
  }

  function setAssetYieldPause(uint32 poolId, address asset, bool isPause) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetYieldPause(msgSender, poolId, asset, isPause);
  }

  function setAssetYieldCap(uint32 poolId, address asset, uint256 cap) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetYieldCap(msgSender, poolId, asset, cap);
  }

  function setAssetYieldRate(uint32 poolId, address asset, address rateModel_) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetAssetYieldRate(msgSender, poolId, asset, rateModel_);
  }

  function setManagerYieldCap(uint32 poolId, address staker, address asset, uint256 cap) public nonReentrant {
    address msgSender = unpackTrailingParamMsgSender();
    ConfigureLogic.executeSetManagerYieldCap(msgSender, poolId, staker, asset, cap);
  }
}
