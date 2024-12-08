// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {ERC721Holder} from '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';

import 'src/PoolManager.sol';
import 'src/modules/BVault.sol';
import 'src/modules/CrossLending.sol';
import 'src/modules/CrossLiquidation.sol';
import 'src/modules/IsolateLending.sol';
import 'src/modules/IsolateLiquidation.sol';
import 'src/modules/Yield.sol';
import 'src/modules/FlashLoan.sol';

import '@forge-std/console.sol';

contract TestUser is ERC721Holder {
  using SafeERC20 for ERC20;

  PoolManager internal _poolManager;
  BVault internal _BVault;
  CrossLending internal _crossLending;
  CrossLiquidation internal _crossLiquidation;
  IsolateLending internal _isolateLending;
  IsolateLiquidation internal _isolateLiquidation;
  Yield internal _yield;
  FlashLoan internal _flashLoan;

  uint256 internal _uid;
  uint256[] internal _tokenIds;

  struct AttckerData {
    uint32 poolId;
    address asset;
    uint8[] groups;
    uint256 amount;
    uint256[] amounts;
    address nftAsset;
    uint256[] tokenIds;
    uint8 supplyMode;
    address onBehalf;
    address receiver;
  }
  AttckerData internal _attackData;
  uint256 internal _attackType;

  constructor(PoolManager poolManager_, uint256 uid_) {
    _poolManager = poolManager_;
    _BVault = BVault(_poolManager.moduleIdToProxy(Constants.MODULEID__BVAULT));
    _crossLending = CrossLending(_poolManager.moduleIdToProxy(Constants.MODULEID__CROSS_LENDING));
    _crossLiquidation = CrossLiquidation(_poolManager.moduleIdToProxy(Constants.MODULEID__CROSS_LIQUIDATION));
    _isolateLending = IsolateLending(_poolManager.moduleIdToProxy(Constants.MODULEID__ISOLATE_LENDING));
    _isolateLiquidation = IsolateLiquidation(_poolManager.moduleIdToProxy(Constants.MODULEID__ISOLATE_LIQUIDATION));
    _yield = Yield(_poolManager.moduleIdToProxy(Constants.MODULEID__YIELD));
    _flashLoan = FlashLoan(_poolManager.moduleIdToProxy(Constants.MODULEID__FLASHLOAN));

    _uid = uid_;
    _tokenIds = new uint256[](3);
    for (uint i = 0; i < 3; i++) {
      _tokenIds[i] = uid_ + i;
    }
  }

  receive() external payable {}

  function getUID() public view returns (uint256) {
    return _uid;
  }

  function getTokenIds() public view returns (uint256[] memory) {
    return _tokenIds;
  }

  function balanceOfNative() public view returns (uint256) {
    return address(this).balance;
  }

  function balanceOf(address token) public view returns (uint256) {
    return ERC20(token).balanceOf(address(this));
  }

  function approveERC20(address token, uint256 amount) public {
    ERC20(token).safeApprove(address(_poolManager), amount);
  }

  function approveERC20(address token, address spender, uint256 amount) public {
    ERC20(token).safeApprove(spender, amount);
  }

  function approveERC721(address token, uint256 tokenId) public {
    ERC721(token).approve(address(_poolManager), tokenId);
  }

  function approveERC721(address token, address spender, uint256 tokenId) public {
    ERC721(token).approve(spender, tokenId);
  }

  function setApprovalForAllERC721(address token, bool val) public {
    ERC721(token).setApprovalForAll(address(_poolManager), val);
  }

  function setApprovalForAllERC721(address token, address spender, bool val) public {
    ERC721(token).setApprovalForAll(spender, val);
  }

  function transferERC20(address token, address to, uint256 amount) public {
    ERC20(token).safeTransfer(to, amount);
  }

  function depositERC20(uint32 poolId, address asset, uint256 amount, address onBehalf) public {
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      uint256 sendVal = amount;
      _BVault.depositERC20{value: sendVal}(poolId, asset, amount, onBehalf);
    } else {
      _BVault.depositERC20(poolId, asset, amount, onBehalf);
    }
  }

  function withdrawERC20(uint32 poolId, address asset, uint256 amount, address onBehalf, address receiver) public {
    _BVault.withdrawERC20(poolId, asset, amount, onBehalf, receiver);
  }

  function depositERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode,
    address onBehalf
  ) public {
    _BVault.depositERC721(poolId, asset, tokenIds, supplyMode, onBehalf);
  }

  function withdrawERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode,
    address onBehalf,
    address receiver
  ) public {
    _BVault.withdrawERC721(poolId, asset, tokenIds, supplyMode, onBehalf, receiver);
  }

  function setERC721SupplyMode(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode,
    address onBehalf
  ) public {
    _BVault.setERC721SupplyMode(poolId, asset, tokenIds, supplyMode, onBehalf);
  }

  function crossBorrowERC20(
    uint32 poolId,
    address asset,
    uint8[] calldata groups,
    uint256[] calldata amounts,
    address onBehalf,
    address receiver
  ) public {
    _crossLending.crossBorrowERC20(poolId, asset, groups, amounts, onBehalf, receiver);
  }

  function crossRepayERC20(
    uint32 poolId,
    address asset,
    uint8[] calldata groups,
    uint256[] calldata amounts,
    address onBehalf
  ) public {
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      uint256 sendVal;
      for (uint i = 0; i < amounts.length; i++) {
        sendVal += amounts[i];
      }
      _crossLending.crossRepayERC20{value: sendVal}(poolId, asset, groups, amounts, onBehalf);
    } else {
      _crossLending.crossRepayERC20(poolId, asset, groups, amounts, onBehalf);
    }
  }

  function crossLiquidateERC20(
    uint32 poolId,
    address borrower,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    bool supplyAsCollateral
  ) public {
    if (debtAsset == Constants.NATIVE_TOKEN_ADDRESS) {
      _crossLiquidation.crossLiquidateERC20{value: debtToCover}(
        poolId,
        borrower,
        collateralAsset,
        debtAsset,
        debtToCover,
        supplyAsCollateral
      );
    } else {
      _crossLiquidation.crossLiquidateERC20(
        poolId,
        borrower,
        collateralAsset,
        debtAsset,
        debtToCover,
        supplyAsCollateral
      );
    }
  }

  function crossLiquidateERC721(
    uint32 poolId,
    address borrower,
    address collateralAsset,
    uint256[] calldata collateralTokenIds,
    address debtAsset,
    bool supplyAsCollateral
  ) public {
    _crossLiquidation.crossLiquidateERC721(
      poolId,
      borrower,
      collateralAsset,
      collateralTokenIds,
      debtAsset,
      supplyAsCollateral
    );
  }

  function crossLiquidateERC721ByNative(
    uint32 poolId,
    address borrower,
    address collateralAsset,
    uint256[] calldata collateralTokenIds,
    bool supplyAsCollateral,
    uint256 msgValue
  ) public {
    address debtAsset = Constants.NATIVE_TOKEN_ADDRESS;
    _crossLiquidation.crossLiquidateERC721{value: msgValue}(
      poolId,
      borrower,
      collateralAsset,
      collateralTokenIds,
      debtAsset,
      supplyAsCollateral
    );
  }

  function isolateBorrow(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts,
    address onBehalf,
    address receiver
  ) public {
    _isolateLending.isolateBorrow(poolId, nftAsset, nftTokenIds, asset, amounts, onBehalf, receiver);
  }

  function isolateRepay(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts,
    address onBehalf
  ) public {
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      uint256 sendVal;
      for (uint i = 0; i < amounts.length; i++) {
        sendVal += amounts[i];
      }
      _isolateLending.isolateRepay{value: sendVal}(poolId, nftAsset, nftTokenIds, asset, amounts, onBehalf);
    } else {
      _isolateLending.isolateRepay(poolId, nftAsset, nftTokenIds, asset, amounts, onBehalf);
    }
  }

  function isolateAuction(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public {
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      uint256 sendVal;
      for (uint i = 0; i < amounts.length; i++) {
        sendVal += amounts[i];
      }
      _isolateLiquidation.isolateAuction{value: sendVal}(poolId, nftAsset, nftTokenIds, asset, amounts);
    } else {
      _isolateLiquidation.isolateAuction(poolId, nftAsset, nftTokenIds, asset, amounts);
    }
  }

  function isolateRedeem(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public {
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      uint256 sendVal;
      for (uint i = 0; i < amounts.length; i++) {
        sendVal += amounts[i];
      }
      _isolateLiquidation.isolateRedeem{value: sendVal}(poolId, nftAsset, nftTokenIds, asset, amounts);
    } else {
      _isolateLiquidation.isolateRedeem(poolId, nftAsset, nftTokenIds, asset, amounts);
    }
  }

  function isolateLiquidate(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts,
    bool supplyAsCollateral
  ) public {
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      uint256 sendVal;
      for (uint i = 0; i < amounts.length; i++) {
        sendVal += amounts[i];
      }
      _isolateLiquidation.isolateLiquidate{value: sendVal}(
        poolId,
        nftAsset,
        nftTokenIds,
        asset,
        amounts,
        supplyAsCollateral
      );
    } else {
      _isolateLiquidation.isolateLiquidate(poolId, nftAsset, nftTokenIds, asset, amounts, supplyAsCollateral);
    }
  }

  function yieldBorrowERC20(uint32 poolId, address asset, uint256 amount) public {
    _yield.yieldBorrowERC20(poolId, asset, amount);
  }

  function yieldRepayERC20(uint32 poolId, address asset, uint256 amount) public {
    _yield.yieldRepayERC20(poolId, asset, amount);
  }

  function flashLoanERC20(
    uint32 poolId,
    address[] calldata assets,
    uint256[] calldata amounts,
    address receiverAddress,
    bytes calldata params
  ) public {
    _flashLoan.flashLoanERC20(poolId, assets, amounts, receiverAddress, params);
  }

  function flashLoanERC721(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[] calldata nftTokenIds,
    address receiverAddress,
    bytes calldata params
  ) public {
    _flashLoan.flashLoanERC721(poolId, nftAssets, nftTokenIds, receiverAddress, params);
  }

  function delegateERC721(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata tokenIds,
    address delegate,
    bool value
  ) public {
    _BVault.delegateERC721(poolId, nftAsset, tokenIds, delegate, value);
  }

  function setAuthorization(uint32 poolId, address asset, address operator, bool approved) public {
    _BVault.setAuthorization(poolId, asset, operator, approved);
  }

  function getReentrantAttackTypes() public pure returns (uint256[] memory attackTypes) {
    attackTypes = new uint256[](9);
    for (uint i = 0; i < 9; i++) {
      attackTypes[i] = i + 1;
    }
  }

  function setAttackType(uint256 attackType_) public {
    _attackType = attackType_;
  }

  function setAttackData(AttckerData memory attackData_) public {
    _attackData = attackData_;
  }

  function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
    if (_attackType == 0) {
      return this.onERC721Received.selector;
    }

    if (_attackType == 1) {
      _BVault.depositERC20(_attackData.poolId, _attackData.asset, _attackData.amount, _attackData.onBehalf);
    }

    if (_attackType == 2) {
      _BVault.withdrawERC20(
        _attackData.poolId,
        _attackData.asset,
        _attackData.amount,
        _attackData.onBehalf,
        _attackData.receiver
      );
    }

    if (_attackType == 3) {
      _BVault.depositERC721(
        _attackData.poolId,
        _attackData.asset,
        _attackData.tokenIds,
        _attackData.supplyMode,
        _attackData.onBehalf
      );
    }

    if (_attackType == 4) {
      _BVault.withdrawERC721(
        _attackData.poolId,
        _attackData.asset,
        _attackData.tokenIds,
        _attackData.supplyMode,
        _attackData.onBehalf,
        _attackData.receiver
      );
    }

    if (_attackType == 5) {
      _BVault.setERC721SupplyMode(
        _attackData.poolId,
        _attackData.asset,
        _attackData.tokenIds,
        _attackData.supplyMode,
        _attackData.onBehalf
      );
    }

    if (_attackType == 6) {
      _crossLending.crossBorrowERC20(
        _attackData.poolId,
        _attackData.asset,
        _attackData.groups,
        _attackData.amounts,
        _attackData.onBehalf,
        _attackData.receiver
      );
    }

    if (_attackType == 7) {
      _crossLending.crossRepayERC20(
        _attackData.poolId,
        _attackData.asset,
        _attackData.groups,
        _attackData.amounts,
        _attackData.onBehalf
      );
    }

    if (_attackType == 8) {
      _isolateLending.isolateBorrow(
        _attackData.poolId,
        _attackData.nftAsset,
        _attackData.tokenIds,
        _attackData.asset,
        _attackData.amounts,
        _attackData.onBehalf,
        _attackData.receiver
      );
    }

    if (_attackType == 9) {
      _isolateLending.isolateRepay(
        _attackData.poolId,
        _attackData.nftAsset,
        _attackData.tokenIds,
        _attackData.asset,
        _attackData.amounts,
        _attackData.onBehalf
      );
    }

    return this.onERC721Received.selector;
  }
}
