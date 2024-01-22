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
import './libraries/logic/YieldLogic.sol';

contract PoolManager is PausableUpgradeable, ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  modifier onlyEmergencyAdmin() {
    _onlyEmergencyAdmin();
    _;
  }

  function _onlyEmergencyAdmin() internal view {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    IACLManager aclManager = IACLManager(ps.aclManager);
    require(aclManager.isEmergencyAdmin(msg.sender), Errors.CALLER_NOT_EMERGENCY_ADMIN);
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(address aclManager_, address priceOracle_) public initializer {
    __Pausable_init();
    __ReentrancyGuard_init();

    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    ps.aclManager = aclManager_;
    ps.priceOracle = priceOracle_;
    ps.nextPoolId = Constants.INITIAL_POOL_ID;
  }

  /****************************************************************************/
  /* Pool Configuration */
  /****************************************************************************/

  function createPool(string memory name) public nonReentrant returns (uint32 poolId) {
    return ConfigureLogic.executeCreatePool(name);
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

  function setAssetAuctionParams(
    uint32 poolId,
    address asset,
    uint16 redeemThreshold,
    uint16 bidFineFactor,
    uint16 minBidFineFactor,
    uint40 auctionDuration
  ) public nonReentrant {
    ConfigureLogic.executeSetAssetAuctionParams(
      poolId,
      asset,
      redeemThreshold,
      bidFineFactor,
      minBidFineFactor,
      auctionDuration
    );
  }

  function setAssetProtocolFee(uint32 poolId, address asset, uint16 feeFactor) public nonReentrant {
    ConfigureLogic.executeSetAssetProtocolFee(poolId, asset, feeFactor);
  }

  function setAssetLendingRate(uint32 poolId, address asset, uint8 groupId, address rateModel_) public nonReentrant {
    ConfigureLogic.executeSetAssetLendingRate(poolId, asset, groupId, rateModel_);
  }

  function setAssetYieldEnable(uint32 poolId, address asset, bool isEnable) public nonReentrant {
    ConfigureLogic.executeSetAssetYieldEnable(poolId, asset, isEnable);
  }

  function setAssetYieldPause(uint32 poolId, address asset, bool isPause) public nonReentrant {
    ConfigureLogic.executeSetAssetYieldPause(poolId, asset, isPause);
  }

  function setAssetYieldCap(uint32 poolId, address asset, uint256 cap) public nonReentrant {
    ConfigureLogic.executeSetAssetYieldCap(poolId, asset, cap);
  }

  function setAssetYieldRate(uint32 poolId, address asset, address rateModel_) public nonReentrant {
    ConfigureLogic.executeSetAssetYieldRate(poolId, asset, rateModel_);
  }

  function setStakerYieldCap(uint32 poolId, address staker, address asset, uint256 cap) public nonReentrant {
    ConfigureLogic.executeSetStakerYieldCap(poolId, staker, asset, cap);
  }

  /****************************************************************************/
  /* Supply */
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

  function withdrawERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode
  ) public whenNotPaused nonReentrant {
    SupplyLogic.executeWithdrawERC721(
      InputTypes.ExecuteWithdrawERC721Params({poolId: poolId, asset: asset, tokenIds: tokenIds, supplyMode: supplyMode})
    );
  }

  function setERC721SupplyMode(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode
  ) public whenNotPaused nonReentrant {
    SupplyLogic.executeSetERC721SupplyMode(
      InputTypes.ExecuteSetERC721SupplyModeParams({
        poolId: poolId,
        asset: asset,
        tokenIds: tokenIds,
        supplyMode: supplyMode
      })
    );
  }

  /****************************************************************************/
  /* Cross Lending */
  /****************************************************************************/

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

  /****************************************************************************/
  /* Isolate Lending */
  /****************************************************************************/

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
    address asset,
    bool supplyAsCollateral
  ) public whenNotPaused nonReentrant {
    IsolateLogic.executeIsolateLiquidate(
      InputTypes.ExecuteIsolateLiquidateParams({
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        supplyAsCollateral: supplyAsCollateral
      })
    );
  }

  /****************************************************************************/
  /* Yield */
  /****************************************************************************/
  function yieldBorrowERC20(uint32 poolId, address asset, uint256 amount) public whenNotPaused nonReentrant {
    YieldLogic.executeYieldBorrowERC20(
      InputTypes.ExecuteYieldBorrowERC20Params({poolId: poolId, asset: asset, amount: amount, isExternalCaller: true})
    );
  }

  function yieldRepayERC20(uint32 poolId, address asset, uint256 amount) public whenNotPaused nonReentrant {
    YieldLogic.executeYieldRepayERC20(
      InputTypes.ExecuteYieldRepayERC20Params({poolId: poolId, asset: asset, amount: amount, isExternalCaller: true})
    );
  }

  /****************************************************************************/
  /* Misc Features */
  /****************************************************************************/

  /****************************************************************************/
  /* Pool Query */
  /****************************************************************************/
  function getPoolMaxAssetNumber() public pure returns (uint256) {
    return Constants.MAX_NUMBER_OF_ASSET;
  }

  function getPoolMaxGroupNumber() public pure returns (uint256) {
    return Constants.MAX_NUMBER_OF_GROUP;
  }

  function getPoolGroupList(uint32 poolId) public view returns (uint256[] memory) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    return poolData.groupList.values();
  }

  function getPoolAssetList(uint32 poolId) public view returns (address[] memory) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    return poolData.assetList.values();
  }

  function getAssetGroupList(uint32 poolId, address asset) public view returns (uint256[] memory) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return assetData.groupList.values();
  }

  function getAssetConfigFlag(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      bool isActive,
      bool isFrozen,
      bool isPaused,
      bool isBorrowingEnabled,
      bool isYieldEnabled,
      bool isYieldPaused
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (
      assetData.isActive,
      assetData.isFrozen,
      assetData.isPaused,
      assetData.isBorrowingEnabled,
      assetData.isYieldEnabled,
      assetData.isYieldPaused
    );
  }

  function getAssetConfigCap(
    uint32 poolId,
    address asset
  ) public view returns (uint256 supplyCap, uint256 borrowCap, uint256 yieldCap) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (assetData.supplyCap, assetData.borrowCap, assetData.yieldCap);
  }

  function getAssetLendingConfig(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      uint8 classGroup,
      uint16 feeFactor,
      uint16 collateralFactor,
      uint16 liquidationThreshold,
      uint16 liquidationBonus
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (
      assetData.classGroup,
      assetData.feeFactor,
      assetData.collateralFactor,
      assetData.liquidationThreshold,
      assetData.liquidationBonus
    );
  }

  function getAssetAuctionConfig(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (uint16 redeemThreshold, uint16 bidFineFactor, uint16 minBidFineFactor, uint40 auctionDuration)
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    return (assetData.redeemThreshold, assetData.bidFineFactor, assetData.minBidFineFactor, assetData.auctionDuration);
  }

  function getAssetSupplyData(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      uint256 totalScaledCrossSupply,
      uint256 totalCrossSupply,
      uint256 totalScaledIsolateSupply,
      uint256 totalIsolateSupply,
      uint256 availableSupply,
      uint256 supplyRate,
      uint256 supplyIndex,
      uint256 lastUpdateTimestamp
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      totalScaledCrossSupply = VaultLogic.erc20GetTotalScaledCrossSupply(assetData);
      totalScaledIsolateSupply = VaultLogic.erc20GetTotalScaledIsolateSupply(assetData);

      uint256 index = InterestLogic.getNormalizedSupplyIncome(assetData);
      totalCrossSupply = VaultLogic.erc20GetTotalCrossSupply(assetData, index);
      totalIsolateSupply = VaultLogic.erc20GetTotalIsolateSupply(assetData, index);
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      totalScaledCrossSupply = totalCrossSupply = VaultLogic.erc721GetTotalCrossSupply(assetData);
      totalScaledIsolateSupply = totalIsolateSupply = VaultLogic.erc721GetTotalIsolateSupply(assetData);
    }

    availableSupply = assetData.availableLiquidity;
    supplyRate = assetData.supplyRate;
    supplyIndex = assetData.supplyIndex;
    lastUpdateTimestamp = assetData.lastUpdateTimestamp;
  }

  function getAssetGroupData(
    uint32 poolId,
    address asset,
    uint8 group
  )
    public
    view
    returns (
      uint256 totalScaledCrossBorrow,
      uint256 totalCrossBorrow,
      uint256 totalScaledIsolateBorrow,
      uint256 totalIsolateBorrow,
      uint256 borrowRate,
      uint256 borrowIndex,
      address rateModel
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[group];

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      totalScaledCrossBorrow = VaultLogic.erc20GetTotalScaledCrossBorrowInGroup(groupData);
      totalScaledIsolateBorrow = VaultLogic.erc20GetTotalScaledIsolateBorrowInGroup(groupData);

      uint256 index = InterestLogic.getNormalizedBorrowDebt(assetData, groupData);
      totalCrossBorrow = VaultLogic.erc20GetTotalCrossBorrowInGroup(groupData, index);
      totalIsolateBorrow = VaultLogic.erc20GetTotalIsolateBorrowInGroup(groupData, index);

      borrowRate = groupData.borrowRate;
      borrowIndex = groupData.borrowIndex;
      rateModel = groupData.rateModel;
    }
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
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    ResultTypes.UserAccountResult memory result = GenericLogic.calculateUserAccountDataForHeathFactor(
      poolData,
      user,
      ps.priceOracle
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

  struct GetUserAssetDataLocalVars {
    uint256 aidx;
    uint256 gidx;
    uint256[] assetGroupIds;
    uint256 index;
  }

  function getUserAssetData(
    address user,
    uint32 poolId,
    address asset
  )
    public
    view
    returns (uint256 totalCrossSupply, uint256 totalIsolateSupply, uint256 totalCrossBorrow, uint256 totalIsolateBorrow)
  {
    GetUserAssetDataLocalVars memory vars;

    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    vars.assetGroupIds = assetData.groupList.values();

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      vars.index = InterestLogic.getNormalizedSupplyIncome(assetData);
      totalCrossSupply = VaultLogic.erc20GetUserCrossSupply(assetData, user, vars.index);

      for (vars.gidx = 0; vars.gidx < vars.assetGroupIds.length; vars.gidx++) {
        DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(vars.assetGroupIds[vars.gidx])];
        vars.index = InterestLogic.getNormalizedBorrowDebt(assetData, groupData);
        totalCrossBorrow += VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, user, vars.index);
        totalIsolateBorrow += VaultLogic.erc20GetUserIsolateBorrowInGroup(groupData, user, vars.index);
      }
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      totalCrossSupply = VaultLogic.erc721GetUserCrossSupply(assetData, user);
      totalIsolateSupply = VaultLogic.erc721GetUserIsolateSupply(assetData, user);
    }
  }

  function getUserAssetScaledData(
    address user,
    uint32 poolId,
    address asset
  )
    public
    view
    returns (
      uint256 totalScaledCrossSupply,
      uint256 totalScaledIsolateSupply,
      uint256 totalScaledCrossBorrow,
      uint256 totalScaledIsolateBorrow
    )
  {
    GetUserAssetDataLocalVars memory vars;

    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];

    vars.assetGroupIds = assetData.groupList.values();

    if (assetData.assetType == Constants.ASSET_TYPE_ERC20) {
      totalScaledCrossSupply = VaultLogic.erc20GetUserScaledCrossSupply(assetData, user);

      for (vars.gidx = 0; vars.gidx < vars.assetGroupIds.length; vars.gidx++) {
        DataTypes.GroupData storage groupData = assetData.groupLookup[uint8(vars.assetGroupIds[vars.gidx])];
        totalScaledCrossBorrow += VaultLogic.erc20GetUserScaledCrossBorrowInGroup(groupData, user);
        totalScaledIsolateBorrow += VaultLogic.erc20GetUserScaledIsolateBorrowInGroup(groupData, user);
      }
    } else if (assetData.assetType == Constants.ASSET_TYPE_ERC721) {
      totalScaledCrossSupply = VaultLogic.erc721GetUserCrossSupply(assetData, user);
      totalScaledIsolateSupply = VaultLogic.erc721GetUserIsolateSupply(assetData, user);
    }
  }

  function getUserAssetGroupData(
    address user,
    uint32 poolId,
    address asset,
    uint8 groupId
  )
    public
    view
    returns (
      uint256 totalScaledCrossBorrow,
      uint256 totalCrossBorrow,
      uint256 totalScaledIsolateBorrow,
      uint256 totalIsolateBorrow
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[groupId];

    totalScaledCrossBorrow = VaultLogic.erc20GetUserScaledCrossBorrowInGroup(groupData, user);
    totalScaledIsolateBorrow = VaultLogic.erc20GetUserScaledIsolateBorrowInGroup(groupData, user);

    uint256 index = InterestLogic.getNormalizedBorrowDebt(assetData, groupData);
    totalCrossBorrow = VaultLogic.erc20GetUserCrossBorrowInGroup(groupData, user, index);
    totalIsolateBorrow = VaultLogic.erc20GetUserIsolateBorrowInGroup(groupData, user, index);
  }

  function getUserAccountDebtData(
    address user,
    uint32 poolId
  )
    public
    view
    returns (
      uint256[] memory groupsCollateralInBase,
      uint256[] memory groupsBorrowInBase,
      uint256[] memory groupsAvailableBorrowInBase
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    ResultTypes.UserAccountResult memory result = GenericLogic.calculateUserAccountDataForHeathFactor(
      poolData,
      user,
      ps.priceOracle
    );

    groupsCollateralInBase = result.allGroupsCollateralInBaseCurrency;
    groupsBorrowInBase = result.allGroupsDebtInBaseCurrency;

    groupsAvailableBorrowInBase = new uint256[](result.allGroupsCollateralInBaseCurrency.length);

    for (uint256 i = 0; i < result.allGroupsCollateralInBaseCurrency.length; i++) {
      groupsAvailableBorrowInBase[i] = GenericLogic.calculateAvailableBorrows(
        result.allGroupsCollateralInBaseCurrency[i],
        result.allGroupsDebtInBaseCurrency[i],
        result.allGroupsAvgLtv[i]
      );
    }
  }

  function getIsolateCollateralData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId,
    address debtAsset
  ) public view returns (uint256 totalCollateral, uint256 totalBorrow, uint256 availableBorrow, uint256 healthFactor) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    DataTypes.AssetData storage nftAssetData = poolData.assetLookup[nftAsset];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[debtAsset];
    DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[nftAssetData.classGroup];
    DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[nftAsset][tokenId];

    ResultTypes.NftLoanResult memory nftLoanResult = GenericLogic.calculateNftLoanData(
      poolData,
      debtAssetData,
      debtGroupData,
      nftAssetData,
      loanData,
      ps.priceOracle
    );

    totalCollateral =
      (nftLoanResult.totalCollateralInBaseCurrency * (10 ** debtAssetData.underlyingDecimals)) /
      nftLoanResult.debtAssetPriceInBaseCurrency;
    totalBorrow =
      (nftLoanResult.totalDebtInBaseCurrency * (10 ** debtAssetData.underlyingDecimals)) /
      nftLoanResult.debtAssetPriceInBaseCurrency;
    availableBorrow = GenericLogic.calculateAvailableBorrows(
      totalCollateral,
      totalBorrow,
      nftAssetData.collateralFactor
    );

    healthFactor = nftLoanResult.healthFactor;
  }

  function getIsolateLoanData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId
  )
    public
    view
    returns (address reserveAsset, uint256 scaledAmount, uint256 borrowAmount, uint8 reserveGroup, uint8 loanStatus)
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[nftAsset][tokenId];
    if (loanData.reserveAsset == address(0)) {
      return (address(0), 0, 0, 0, 0);
    }

    DataTypes.AssetData storage assetData = poolData.assetLookup[loanData.reserveAsset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[loanData.reserveGroup];

    reserveAsset = loanData.reserveAsset;
    scaledAmount = loanData.scaledAmount;
    borrowAmount = scaledAmount.rayMul(InterestLogic.getNormalizedBorrowDebt(assetData, groupData));
    reserveGroup = loanData.reserveGroup;
    loanStatus = loanData.loanStatus;
  }

  function getIsolateAuctionData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId
  )
    public
    view
    returns (
      uint40 bidStartTimestamp,
      uint40 bidEndTimestamp,
      address firstBidder,
      address lastBidder,
      uint256 bidAmount,
      uint256 bidFine,
      uint256 redeemAmount
    )
  {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];

    DataTypes.IsolateLoanData storage loanData = poolData.loanLookup[nftAsset][tokenId];
    if (loanData.loanStatus != Constants.LOAN_STATUS_AUCTION) {
      return (0, 0, address(0), address(0), 0, 0, 0);
    }

    DataTypes.AssetData storage nftAssetData = poolData.assetLookup[nftAsset];
    DataTypes.AssetData storage debtAssetData = poolData.assetLookup[loanData.reserveAsset];
    DataTypes.GroupData storage debtGroupData = debtAssetData.groupLookup[loanData.reserveGroup];

    bidStartTimestamp = loanData.bidStartTimestamp;
    bidEndTimestamp = loanData.bidStartTimestamp + nftAssetData.auctionDuration;
    firstBidder = loanData.firstBidder;
    lastBidder = loanData.lastBidder;
    bidAmount = loanData.bidAmount;

    (, bidFine) = GenericLogic.calculateNftLoanBidFine(
      poolData,
      debtAssetData,
      debtGroupData,
      nftAssetData,
      loanData,
      ps.priceOracle
    );

    uint256 normalizedIndex = InterestLogic.getNormalizedBorrowDebt(debtAssetData, debtGroupData);
    uint256 borrowAmount = loanData.scaledAmount.rayMul(normalizedIndex);
    redeemAmount = borrowAmount.percentMul(nftAssetData.redeemThreshold);
  }

  function getYieldERC20BorrowBalance(uint32 poolId, address asset, address staker) public view returns (uint256) {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
    DataTypes.PoolData storage poolData = ps.poolLookup[poolId];
    DataTypes.AssetData storage assetData = poolData.assetLookup[asset];
    DataTypes.GroupData storage groupData = assetData.groupLookup[poolData.yieldGroup];

    uint256 scaledBalance = VaultLogic.erc20GetUserScaledCrossBorrowInGroup(groupData, staker);
    return scaledBalance.rayMul(InterestLogic.getNormalizedBorrowDebt(assetData, groupData));
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
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolLendingStorage();
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
