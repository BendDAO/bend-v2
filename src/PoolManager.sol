// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';
import {ERC721HolderUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

import './libraries/helpers/Constants.sol';
import './libraries/helpers/Errors.sol';
import './libraries/types/DataTypes.sol';
import './libraries/types/InputTypes.sol';

import './libraries/logic/StorageSlot.sol';
import './libraries/logic/ConfigureLogic.sol';
import './libraries/logic/VaultLogic.sol';
import './libraries/logic/SupplyLogic.sol';
import './libraries/logic/BorrowLogic.sol';
import './libraries/logic/LiquidationLogic.sol';

contract PoolManager is PausableUpgradeable, ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  constructor() {
    _disableInitializers();
  }

  function initialize(address aclManager_, address priceOracle_) public initializer {
    __Pausable_init();
    __ReentrancyGuard_init();

    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    cs.aclManager = aclManager_;
    cs.priceOracle = priceOracle_;

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    ps.nextPoolId = 1;
  }

  function createPool() public nonReentrant returns (uint32 poolId) {
    return ConfigureLogic.executeCreatePool();
  }

  function deletePool(uint32 poolId) public nonReentrant {
    return ConfigureLogic.executeDeletePool(poolId);
  }

  function addAssetERC20(uint32 poolId, address underlyingAsset, uint8 riskGroupId) public nonReentrant {
    return ConfigureLogic.executeAddAssetERC20(poolId, underlyingAsset, riskGroupId);
  }

  function removeAssetERC20(uint32 poolId, address underlyingAsset) public nonReentrant {
    return ConfigureLogic.executeRemoveAssetERC20(poolId, underlyingAsset);
  }

  function addAssetERC721(uint32 poolId, address underlyingAsset, uint8 riskGroupId) public nonReentrant {
    return ConfigureLogic.executeAddAssetERC721(poolId, underlyingAsset, riskGroupId);
  }

  function removeAssetERC721(uint32 poolId, address underlyingAsset) public nonReentrant {
    return ConfigureLogic.executeRemoveAssetERC721(poolId, underlyingAsset);
  }

  function addGroup(
    uint32 poolId,
    address underlyingAsset,
    address rateModel_
  ) public nonReentrant returns (uint8 groupId) {
    return ConfigureLogic.executeAddGroup(poolId, underlyingAsset, rateModel_);
  }

  function removeGroup(uint32 poolId, address underlyingAsset, uint8 groupId) public nonReentrant {
    return ConfigureLogic.executeRemoveGroup(poolId, underlyingAsset, groupId);
  }

  function setAssetRiskGroup(uint32 poolId, address underlyingAsset, uint8 riskGroupId) public nonReentrant {
    return ConfigureLogic.executeSetAssetRiskGroup(poolId, underlyingAsset, riskGroupId);
  }

  function setGroupInterestRateModel(
    uint32 poolId,
    address underlyingAsset,
    uint8 groupId,
    address rateModel_
  ) public nonReentrant {
    return ConfigureLogic.executeSetGroupInterestRateModel(poolId, underlyingAsset, groupId, rateModel_);
  }

  function depositERC20(uint32 poolId, address asset, uint256 amount) public nonReentrant {
    SupplyLogic.executeDepositERC20(
      InputTypes.ExecuteDepositERC20Params({poolId: poolId, asset: asset, amount: amount})
    );
  }

  function withdrawERC20(uint32 poolId, address asset, uint256 amount, address to) public nonReentrant {
    SupplyLogic.executeWithdrawERC20(
      InputTypes.ExecuteWithdrawERC20Params({poolId: poolId, asset: asset, amount: amount, to: to})
    );
  }

  function depositERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint256 supplyMode
  ) public nonReentrant {
    SupplyLogic.executeDepositERC721(
      InputTypes.ExecuteDepositERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds, supplyMode: supplyMode})
    );
  }

  function withdrawERC721(uint32 poolId, address asset, uint256[] calldata tokenIds, address to) public nonReentrant {
    SupplyLogic.executeWithdrawERC721(
      InputTypes.ExecuteWithdrawERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds, to: to})
    );
  }

  function borrowERC20(uint32 poolId, address asset, uint256 amount, address to) public nonReentrant {
    BorrowLogic.executeBorrowERC20(
      InputTypes.ExecuteBorrowERC20Params({poolId: poolId, asset: asset, amount: amount, to: to})
    );
  }

  function repayERC20(uint32 poolId, address asset, uint256 amount) public nonReentrant {
    BorrowLogic.executeRepayERC20(InputTypes.ExecuteRepayERC20Params({poolId: poolId, asset: asset, amount: amount}));
  }

  function liquidateERC20(
    uint32 poolId,
    address user,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    bool supplyAsCollateral
  ) public nonReentrant {
    LiquidationLogic.executeLiquidateERC20(
      InputTypes.ExecuteLiquidateERC20Params({
        poolId: poolId,
        user: user,
        collateralAsset: collateralAsset,
        debtAsset: debtAsset,
        debtToCover: debtToCover,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }

  function liquidateERC721(
    uint32 poolId,
    address user,
    address collateralAsset,
    uint256[] calldata collateralTokenIds,
    address debtAsset,
    bool supplyAsCollateral
  ) public nonReentrant {
    LiquidationLogic.executeLiquidateERC721(
      InputTypes.ExecuteLiquidateERC721Params({
        poolId: poolId,
        user: user,
        collateralAsset: collateralAsset,
        collateralTokenIds: collateralTokenIds,
        debtAsset: debtAsset,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }
}
