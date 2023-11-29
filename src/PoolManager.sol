// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import {ERC721HolderUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import {IACLManager} from './interfaces/IACLManager.sol';
import {IWETH} from './interfaces/IWETH.sol';

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
import './libraries/logic/IsolateLogic.sol';

import './EscrowAccount.sol';

contract PoolManager is PausableUpgradeable, ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using WadRayMath for uint256;

  modifier onlyEmergencyAdmin() {
    _onlyEmergencyAdmin();
    _;
  }

  function _onlyEmergencyAdmin() internal view {
    DataTypes.CommonStorage storage cs = StorageSlot.getCommonStorage();
    IACLManager aclManager = IACLManager(cs.aclManager);
    require(aclManager.isEmergencyAdmin(msg.sender), Errors.CALLER_NOT_EMERGENCY_ADMIN);
  }

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
    ps.isolateEscrowAccount = address(new EscrowAccount(address(this)));
  }

  /****************************************************************************/
  /* Pool Configuration */
  /****************************************************************************/

  function createPool() public nonReentrant returns (uint32 poolId) {
    return ConfigureLogic.executeCreatePool();
  }

  function deletePool(uint32 poolId) public nonReentrant {
    ConfigureLogic.executeDeletePool(poolId);
  }

  function addPoolGroup(uint32 poolId, uint8 groupId) public nonReentrant {
    return ConfigureLogic.executeAddPoolGroup(poolId, groupId);
  }

  function removePoolGroup(uint32 poolId, uint8 groupId) public nonReentrant {
    ConfigureLogic.executeRemovePoolGroup(poolId, groupId);
  }

  function setPoolYieldEnable(uint32 poolId, bool isEnable) public nonReentrant {
    ConfigureLogic.executeSetPoolYieldEnable(poolId, isEnable);
  }

  function setPoolYieldPause(uint32 poolId, bool isPause) public nonReentrant {
    ConfigureLogic.executeSetPoolYieldPause(poolId, isPause);
  }

  function addAssetERC20(uint32 poolId, address asset) public nonReentrant {
    ConfigureLogic.executeAddAssetERC20(poolId, asset);
  }

  function removeAssetERC20(uint32 poolId, address asset) public nonReentrant {
    ConfigureLogic.executeRemoveAssetERC20(poolId, asset);
  }

  function addAssetERC721(uint32 poolId, address asset) public nonReentrant {
    ConfigureLogic.executeAddAssetERC721(poolId, asset);
  }

  function removeAssetERC721(uint32 poolId, address asset) public nonReentrant {
    ConfigureLogic.executeRemoveAssetERC721(poolId, asset);
  }

  function addAssetGroup(uint32 poolId, address asset, uint8 groupId, address rateModel_) public nonReentrant {
    ConfigureLogic.executeAddAssetGroup(poolId, asset, groupId, rateModel_);
  }

  function removeAssetGroup(uint32 poolId, address asset, uint8 groupId) public nonReentrant {
    ConfigureLogic.executeRemoveAssetGroup(poolId, asset, groupId);
  }

  function setAssetActive(uint32 poolId, address asset, bool isActive) public nonReentrant {
    ConfigureLogic.executeSetAssetActive(poolId, asset, isActive);
  }

  function setAssetFrozen(uint32 poolId, address asset, bool isFrozen) public nonReentrant {
    ConfigureLogic.executeSetAssetFrozen(poolId, asset, isFrozen);
  }

  function setAssetPause(uint32 poolId, address asset, bool isPause) public nonReentrant {
    ConfigureLogic.executeSetAssetPause(poolId, asset, isPause);
  }

  function setAssetBorrowing(uint32 poolId, address asset, bool isEnable) public nonReentrant {
    ConfigureLogic.executeSetAssetBorrowing(poolId, asset, isEnable);
  }

  function setAssetSupplyCap(uint32 poolId, address asset, uint256 newCap) public nonReentrant {
    ConfigureLogic.executeSetAssetSupplyCap(poolId, asset, newCap);
  }

  function setAssetBorrowCap(uint32 poolId, address asset, uint256 newCap) public nonReentrant {
    ConfigureLogic.executeSetAssetBorrowCap(poolId, asset, newCap);
  }

  function setAssetClassGroup(uint32 poolId, address asset, uint8 classGroup) public nonReentrant {
    ConfigureLogic.executeSetAssetClassGroup(poolId, asset, classGroup);
  }

  function setAssetCollateralParams(
    uint32 poolId,
    address asset,
    uint16 collateralFactor,
    uint16 liquidationThreshold,
    uint16 liquidationBonus
  ) public nonReentrant {
    ConfigureLogic.executeSetAssetCollateralParams(
      poolId,
      asset,
      collateralFactor,
      liquidationThreshold,
      liquidationBonus
    );
  }

  function setAssetProtocolFee(uint32 poolId, address asset, uint16 feeFactor) public nonReentrant {
    ConfigureLogic.executeSetAssetProtocolFee(poolId, asset, feeFactor);
  }

  function setAssetInterestRateModel(
    uint32 poolId,
    address asset,
    uint8 groupId,
    address rateModel_
  ) public nonReentrant {
    ConfigureLogic.executeSetAssetInterestRateModel(poolId, asset, groupId, rateModel_);
  }

  function setAssetYieldEnable(uint32 poolId, address asset, bool isEnable) public nonReentrant {
    ConfigureLogic.executeSetAssetYieldEnable(poolId, asset, isEnable);
  }

  function setAssetYieldPause(uint32 poolId, address asset, bool isPause) public nonReentrant {
    ConfigureLogic.executeSetAssetYieldPause(poolId, asset, isPause);
  }

  function setAssetYieldCap(uint32 poolId, address asset, address staker, uint256 cap) public nonReentrant {
    ConfigureLogic.executeSetAssetYieldCap(poolId, asset, staker, cap);
  }

  /****************************************************************************/
  /* Pool Lending */
  /****************************************************************************/

  function depositERC20(uint32 poolId, address asset, uint256 amount) public whenNotPaused nonReentrant {
    SupplyLogic.executeDepositERC20(
      InputTypes.ExecuteDepositERC20Params({poolId: poolId, asset: asset, amount: amount})
    );
  }

  function withdrawERC20(uint32 poolId, address asset, uint256 amount) public whenNotPaused nonReentrant {
    SupplyLogic.executeWithdrawERC20(
      InputTypes.ExecuteWithdrawERC20Params({poolId: poolId, asset: asset, amount: amount})
    );
  }

  function depositERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode
  ) public whenNotPaused nonReentrant {
    SupplyLogic.executeDepositERC721(
      InputTypes.ExecuteDepositERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds, supplyMode: supplyMode})
    );
  }

  function withdrawERC721(uint32 poolId, address asset, uint256[] calldata tokenIds) public whenNotPaused nonReentrant {
    SupplyLogic.executeWithdrawERC721(
      InputTypes.ExecuteWithdrawERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds})
    );
  }

  function crossBorrowERC20(
    uint32 poolId,
    address asset,
    uint8[] calldata groups,
    uint256[] calldata amounts
  ) public whenNotPaused nonReentrant {
    BorrowLogic.executeCrossBorrowERC20(
      InputTypes.ExecuteCrossBorrowERC20Params({poolId: poolId, asset: asset, groups: groups, amounts: amounts})
    );
  }

  function crossRepayERC20(
    uint32 poolId,
    address asset,
    uint8[] calldata groups,
    uint256[] calldata amounts
  ) public whenNotPaused nonReentrant {
    BorrowLogic.executeCrossRepayERC20(
      InputTypes.ExecuteCrossRepayERC20Params({poolId: poolId, asset: asset, groups: groups, amounts: amounts})
    );
  }

  function crossLiquidateERC20(
    uint32 poolId,
    address user,
    address collateralAsset,
    address debtAsset,
    uint256 debtToCover,
    bool supplyAsCollateral
  ) public whenNotPaused nonReentrant {
    LiquidationLogic.executeCrossLiquidateERC20(
      InputTypes.ExecuteCrossLiquidateERC20Params({
        poolId: poolId,
        user: user,
        collateralAsset: collateralAsset,
        debtAsset: debtAsset,
        debtToCover: debtToCover,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }

  function crossLiquidateERC721(
    uint32 poolId,
    address user,
    address collateralAsset,
    uint256[] calldata collateralTokenIds,
    address debtAsset,
    bool supplyAsCollateral
  ) public whenNotPaused nonReentrant {
    LiquidationLogic.executeCrossLiquidateERC721(
      InputTypes.ExecuteCrossLiquidateERC721Params({
        poolId: poolId,
        user: user,
        collateralAsset: collateralAsset,
        collateralTokenIds: collateralTokenIds,
        debtAsset: debtAsset,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }

  function isolateBorrow(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public whenNotPaused nonReentrant {
    IsolateLogic.executeIsolateBorrow(
      InputTypes.ExecuteIsolateBorrowParams({
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        amounts: amounts
      })
    );
  }

  function isolateRepay(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public whenNotPaused nonReentrant {
    IsolateLogic.executeIsolateRepay(
      InputTypes.ExecuteIsolateRepayParams({
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        amounts: amounts
      })
    );
  }

  function isolateAuction(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public whenNotPaused nonReentrant {
    IsolateLogic.executeIsolateAuction(
      InputTypes.ExecuteIsolateAuctionParams({
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        amounts: amounts
      })
    );
  }

  function isolateRedeem(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset
  ) public whenNotPaused nonReentrant {
    IsolateLogic.executeIsolateRedeem(
      InputTypes.ExecuteIsolateRedeemParams({
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset
      })
    );
  }

  function isolateLiquidate(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset
  ) public whenNotPaused nonReentrant {
    IsolateLogic.executeIsolateLiquidate(
      InputTypes.ExecuteIsolateLiquidateParams({
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset
      })
    );
  }

  function setERC721SupplyMode(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds
  ) public whenNotPaused nonReentrant {}

  function moveERC20BetweenPools(
    uint32 fromPoolId,
    address asset,
    uint256 amount,
    uint32 toPoolId
  ) public whenNotPaused nonReentrant {}

  function moveERC721BetweenPools(
    uint32 fromPoolId,
    address asset,
    uint256[] calldata tokenIds,
    uint32 toPoolId
  ) public whenNotPaused nonReentrant {}

  /****************************************************************************/
  /* Pool Query */
  /****************************************************************************/
  function getPoolGroupList(uint32 poolId) public view returns (uint256[] memory) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    return poolData.groupList.values();
  }

  function getPoolAssetList(uint32 poolId) public view returns (address[] memory) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    return poolData.assetList.values();
  }

  function getAssetGroupList(uint32 poolId, address asset) public view returns (uint256[] memory) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return assetData.groupList.values();
  }

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

  function getUserGroupData(
    uint32 poolId,
    address user,
    uint8[] calldata groupIds
  )
    public
    view
    returns (
      uint256[] memory groupsCollateralInBase,
      uint256[] memory groupsBorrowInBase,
      uint256[] memory groupsAvailableBorrowInBase
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

    for (uint256 i = 0; i < groupIds.length; i++) {
      groupsCollateralInBase[i] = result.allGroupsCollateralInBaseCurrency[groupIds[i]];
      groupsBorrowInBase[i] = result.allGroupsDebtInBaseCurrency[groupIds[i]];

      groupsAvailableBorrowInBase[i] = GenericLogic.calculateAvailableBorrows(
        result.allGroupsCollateralInBaseCurrency[groupIds[i]],
        result.allGroupsDebtInBaseCurrency[groupIds[i]],
        result.allGroupsAvgLtv[groupIds[i]]
      );
    }
  }

  struct GetUserAssetDataLocalVars {
    uint256 aidx;
    uint256 gidx;
    uint256[] assetGroupIds;
    uint256 scaledSupply;
    uint256 scaledBorrow;
  }

  function getUserAssetData(
    uint32 poolId,
    address user,
    address[] calldata assets
  )
    public
    view
    returns (
      uint256[] memory totalCrossSupplies,
      uint256[] memory totalIsolateSupplies,
      uint256[] memory totalCrossBorrows,
      uint256[] memory totalIsolateBorrows
    )
  {
    GetUserAssetDataLocalVars memory vars;

    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    for (vars.aidx = 0; vars.aidx < assets.length; vars.aidx++) {
      DataTypes.AssetData storage assetData = poolData.assetLookup[assets[vars.aidx]];
      vars.assetGroupIds = assetData.groupList.values();

      if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
        vars.scaledSupply = VaultLogic.erc20GetUserScaledSupply(assetData, user);
        totalCrossSupplies[vars.aidx] = vars.scaledSupply.rayMul(InterestLogic.getNormalizedSupplyIncome(assetData));

        for (vars.gidx = 0; vars.gidx < vars.assetGroupIds.length; vars.gidx++) {
          DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(vars.assetGroupIds[vars.gidx])];
          vars.scaledBorrow = VaultLogic.erc20GetUserScaledBorrowInGroup(groupData, user);
          totalCrossBorrows[vars.aidx] += vars.scaledBorrow.rayMul(InterestLogic.getNormalizedBorrowDebt(groupData));
        }

        // TODO: isolate borrow
        totalIsolateBorrows[vars.aidx] = 0;
      } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
        totalCrossSupplies[vars.aidx] = VaultLogic.erc721GetUserCrossSupply(assetData, user);
        totalIsolateSupplies[vars.aidx] = VaultLogic.erc721GetUserIsolateSupply(assetData, user);
      }
    }
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

    return VaultLogic.erc20GetUserScaledBorrowInGroup(groupData, user);
  }

  function getUserERC20ScaledBorrowBalance(uint32 poolId, address asset, address user) public view returns (uint256) {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    uint256 totalScaledBalance = 0;
    uint256[] memory assetGroupIds = assetData.groupList.values();
    for (uint256 i = 0; i < assetGroupIds.length; i++) {
      DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(assetGroupIds[i])];
      totalScaledBalance += VaultLogic.erc20GetUserScaledBorrowInGroup(groupData, user);
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

    uint256 scaledBalance = VaultLogic.erc20GetUserScaledBorrowInGroup(groupData, user);
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
      uint256 scaledBalance = VaultLogic.erc20GetUserScaledBorrowInGroup(groupData, user);
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

  // Pool Admin
  /**
   * @dev Pauses or unpauses the whole protocol.
   */
  function setGlobalPause(bool paused) public onlyEmergencyAdmin {
    if (paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  /**
   * @dev Pauses or unpauses all the assets in the pool.
   */
  function setPoolPause(uint32 poolId, bool paused) public onlyEmergencyAdmin {
    DataTypes.PoolLendingStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    address[] memory assets = poolData.assetList.values();

    for (uint256 i = 0; i < assets.length; i++) {
      if (assets[i] != address(0)) {
        setAssetPause(poolId, assets[i], paused);
      }
    }
  }

  /**
   * @dev transfer ETH to an address, revert if it fails.
   */
  function _safeTransferETH(address to, uint256 value) internal {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, 'ETH_TRANSFER_FAILED');
  }
}
