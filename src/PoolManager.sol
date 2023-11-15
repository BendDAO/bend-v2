// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import {ERC721HolderUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import './libraries/helpers/Constants.sol';
import './libraries/helpers/Errors.sol';
import './libraries/types/DataTypes.sol';
import './libraries/types/InputTypes.sol';
import './libraries/types/ResultTypes.sol';

import './libraries/logic/StorageSlot.sol';
import './libraries/logic/GenericLogic.sol';
import './libraries/logic/ConfigureLogic.sol';
import './libraries/logic/VaultLogic.sol';
import './libraries/logic/SupplyLogic.sol';
import './libraries/logic/BorrowLogic.sol';
import './libraries/logic/LiquidationLogic.sol';

contract PoolManager is PausableUpgradeable, ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using WadRayMath for uint256;

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

  /****************************************************************************/
  /* Pool Configuration */
  /****************************************************************************/

  function createPool() public nonReentrant returns (uint32 poolId) {
    return ConfigureLogic.executeCreatePool();
  }

  function deletePool(uint32 poolId) public nonReentrant {
    return ConfigureLogic.executeDeletePool(poolId);
  }

  function addPoolGroup(uint32 poolId) public nonReentrant returns (uint8 groupId) {
    return ConfigureLogic.executeAddPoolGroup(poolId);
  }

  function removePoolGroup(uint32 poolId, uint8 groupId) public nonReentrant {
    return ConfigureLogic.executeRemovePoolGroup(poolId, groupId);
  }

  function addAssetERC20(uint32 poolId, address underlyingAsset) public nonReentrant {
    return ConfigureLogic.executeAddAssetERC20(poolId, underlyingAsset);
  }

  function removeAssetERC20(uint32 poolId, address underlyingAsset) public nonReentrant {
    return ConfigureLogic.executeRemoveAssetERC20(poolId, underlyingAsset);
  }

  function addAssetERC721(uint32 poolId, address underlyingAsset) public nonReentrant {
    return ConfigureLogic.executeAddAssetERC721(poolId, underlyingAsset);
  }

  function removeAssetERC721(uint32 poolId, address underlyingAsset) public nonReentrant {
    return ConfigureLogic.executeRemoveAssetERC721(poolId, underlyingAsset);
  }

  function addAssetGroup(
    uint32 poolId,
    address underlyingAsset,
    uint8 groupId,
    address rateModel_
  ) public nonReentrant {
    return ConfigureLogic.executeAddAssetGroup(poolId, underlyingAsset, groupId, rateModel_);
  }

  function removeAssetGroup(uint32 poolId, address underlyingAsset, uint8 groupId) public nonReentrant {
    return ConfigureLogic.executeRemoveAssetGroup(poolId, underlyingAsset, groupId);
  }

  function setAssetActive(uint32 poolId, address underlyingAsset, bool isActive) public nonReentrant {
    return ConfigureLogic.executeSetAssetActive(poolId, underlyingAsset, isActive);
  }

  function setAssetFrozen(uint32 poolId, address underlyingAsset, bool isFrozen) public nonReentrant {
    return ConfigureLogic.executeSetAssetFrozen(poolId, underlyingAsset, isFrozen);
  }

  function setAssetPause(uint32 poolId, address underlyingAsset, bool isPause) public nonReentrant {
    return ConfigureLogic.executeSetAssetPause(poolId, underlyingAsset, isPause);
  }

  function setAssetBorrowing(uint32 poolId, address underlyingAsset, bool isEnable) public nonReentrant {
    return ConfigureLogic.executeSetAssetBorrowing(poolId, underlyingAsset, isEnable);
  }

  function setAssetRiskGroup(uint32 poolId, address underlyingAsset, uint8 riskGroupId) public nonReentrant {
    return ConfigureLogic.executeSetAssetRiskGroup(poolId, underlyingAsset, riskGroupId);
  }

  function setAssetCollateralParams(
    uint32 poolId,
    address underlyingAsset,
    uint16 collateralFactor,
    uint16 liquidationThreshold,
    uint16 liquidationBonus
  ) public nonReentrant {
    return
      ConfigureLogic.executeSetAssetCollateralParams(
        poolId,
        underlyingAsset,
        collateralFactor,
        liquidationThreshold,
        liquidationBonus
      );
  }

  function setAssetProtocolFee(uint32 poolId, address underlyingAsset, uint16 feeFactor) public nonReentrant {
    return ConfigureLogic.executeSetAssetProtocolFee(poolId, underlyingAsset, feeFactor);
  }

  function setAssetInterestRateModel(
    uint32 poolId,
    address underlyingAsset,
    uint8 groupId,
    address rateModel_
  ) public nonReentrant {
    return ConfigureLogic.executeSetAssetInterestRateModel(poolId, underlyingAsset, groupId, rateModel_);
  }

  /****************************************************************************/
  /* Pool Lending */
  /****************************************************************************/

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

  function borrowERC20(uint32 poolId, address asset, uint8 group, uint256 amount, address to) public nonReentrant {
    BorrowLogic.executeBorrowERC20(
      InputTypes.ExecuteBorrowERC20Params({poolId: poolId, asset: asset, group: group, amount: amount, to: to})
    );
  }

  function repayERC20(uint32 poolId, address asset, uint8 group, uint256 amount) public nonReentrant {
    BorrowLogic.executeRepayERC20(
      InputTypes.ExecuteRepayERC20Params({poolId: poolId, asset: asset, group: group, amount: amount})
    );
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

  /****************************************************************************/
  /* Pool Query */
  /****************************************************************************/
  function getAssetSupplyData(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      uint256 totalCrossSupplied,
      uint256 totalIsolateSupplied,
      uint256 availableSupply,
      uint256 supplyRate,
      uint256 supplyIndex
    )
  {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    totalCrossSupplied = assetData.totalCrossSupplied;
    totalIsolateSupplied = assetData.totalIsolateSupplied;
    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      availableSupply = IERC20Upgradeable(asset).balanceOf(address(this));
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      availableSupply = IERC721Upgradeable(asset).balanceOf(address(this));
    }
    supplyRate = assetData.supplyRate;
    supplyIndex = assetData.supplyIndex;
  }

  function getAssetBorrowData(
    uint32 poolId,
    address asset,
    uint8 group
  )
    public
    view
    returns (uint256 totalCrossBorrow, uint256 totalIsolateBorrow, uint256 borrowRate, uint256 borrowIndex)
  {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[group];

    totalCrossBorrow = groupData.totalCrossBorrowed;
    totalIsolateBorrow = groupData.totalIsolateBorrowed;
    borrowRate = groupData.borrowRate;
    borrowIndex = groupData.borrowIndex;
  }

  function getUserAccountData(
    uint32 poolId,
    address user
  )
    public
    view
    returns (
      uint256 totalCollateralInBase,
      uint256 totalBorrowInBase,
      uint256 availableBorrowInBase,
      uint256 currentCollateralFactor,
      uint256 currentLiquidationThreshold,
      uint256 healthFactor
    )
  {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    ResultTypes.UserAccountResult memory result = GenericLogic.calculateUserAccountDataForHeathFactor(
      poolData,
      user,
      cs.priceOracle
    );

    totalCollateralInBase = result.totalCollateralInBaseCurrency;
    totalBorrowInBase = result.totalDebtInBaseCurrency;
    availableBorrowInBase = GenericLogic.calculateAvailableBorrows(
      totalCollateralInBase,
      totalBorrowInBase,
      result.avgLtv
    );

    currentCollateralFactor = result.avgLtv;
    currentLiquidationThreshold = result.avgLiquidationThreshold;
    healthFactor = result.healthFactor;
  }

  function getUserERC20ScaledSupplyBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return VaultLogic.erc20GetUserScaledSupply(assetData, user);
  }

  function getUserERC20SupplyBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    uint256 scaledBalance = VaultLogic.erc20GetUserScaledSupply(assetData, user);
    return scaledBalance.rayMul(InterestLogic.getNormalizedSupplyIncome(assetData));
  }

  function getUserERC20ScaledBorrowBalance(
    uint32 poolId,
    address asset,
    uint8 group,
    address user
  ) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[group];

    return VaultLogic.erc20GetUserScaledBorrow(groupData, user);
  }

  function getUserERC20ScaledBorrowBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    uint256 totalScaledBalance = 0;
    uint256[] memory assetGroupIds = assetData.groupList.values();
    for (uint256 i = 0; i < assetGroupIds.length; i++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(assetGroupIds[i])];
      totalScaledBalance += VaultLogic.erc20GetUserScaledBorrow(groupData, user);
    }

    return totalScaledBalance;
  }

  function getUserERC20BorrowBalance(
    uint32 poolId,
    address asset,
    uint8 group,
    address user
  ) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[group];

    uint256 scaledBalance = VaultLogic.erc20GetUserScaledBorrow(groupData, user);
    return scaledBalance.rayMul(InterestLogic.getNormalizedBorrowDebt(groupData));
  }

  function getUserERC20BorrowBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    uint256 totalBalance = 0;
    uint256[] memory assetGroupIds = assetData.groupList.values();
    for (uint256 i = 0; i < assetGroupIds.length; i++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(assetGroupIds[i])];
      uint256 scaledBalance = VaultLogic.erc20GetUserScaledBorrow(groupData, user);
      totalBalance += scaledBalance.rayMul(InterestLogic.getNormalizedBorrowDebt(groupData));
    }

    return totalBalance;
  }

  function getUserERC721SupplyBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return
      VaultLogic.erc721GetUserCrossSupply(assetData, user) + VaultLogic.erc721GetUserIsolateSupply(assetData, user);
  }

  function getUserERC721CrossSupplyBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return VaultLogic.erc721GetUserCrossSupply(assetData, user);
  }

  function getUserERC721IsolateSupplyBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return VaultLogic.erc721GetUserIsolateSupply(assetData, user);
  }
}
