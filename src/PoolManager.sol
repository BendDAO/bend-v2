// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import {AddressUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol';
import {ERC721HolderUpgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import {IAddressProvider} from './interfaces/IAddressProvider.sol';
import {IACLManager} from './interfaces/IACLManager.sol';
import {IWETH} from './interfaces/IWETH.sol';

import {Constants} from './libraries/helpers/Constants.sol';
import {Errors} from './libraries/helpers/Errors.sol';
import {DataTypes} from './libraries/types/DataTypes.sol';
import {InputTypes} from './libraries/types/InputTypes.sol';

import {StorageSlot} from './libraries/logic/StorageSlot.sol';
import {VaultLogic} from './libraries/logic/VaultLogic.sol';
import {ConfigureLogic} from './libraries/logic/ConfigureLogic.sol';
import {SupplyLogic} from './libraries/logic/SupplyLogic.sol';
import {BorrowLogic} from './libraries/logic/BorrowLogic.sol';
import {LiquidationLogic} from './libraries/logic/LiquidationLogic.sol';
import {IsolateLogic} from './libraries/logic/IsolateLogic.sol';
import {YieldLogic} from './libraries/logic/YieldLogic.sol';
import {FlashLoanLogic} from './libraries/logic/FlashLoanLogic.sol';
import {QueryLogic} from './libraries/logic/QueryLogic.sol';
import {PoolLogic} from './libraries/logic/PoolLogic.sol';

contract PoolManager is PausableUpgradeable, ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
  constructor() {
    _disableInitializers();
  }

  function initialize(address provider_) public initializer {
    require(provider_ != address(0), Errors.INVALID_ADDRESS);

    __Pausable_init();
    __ReentrancyGuard_init();
    __ERC721Holder_init();

    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    ps.addressProvider = provider_;
    ps.nextPoolId = Constants.INITIAL_POOL_ID;

    ps.wrappedNativeToken = IAddressProvider(ps.addressProvider).getWrappedNativeToken();
    require(ps.wrappedNativeToken != address(0), Errors.INVALID_ADDRESS);
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

  function setPoolPause(uint32 poolId, bool paused) public nonReentrant {
    ConfigureLogic.executeSetPoolPause(poolId, paused);
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

  function setAssetFlashLoan(uint32 poolId, address asset, bool isEnable) public nonReentrant {
    ConfigureLogic.executeSetAssetFlashLoan(poolId, asset, isEnable);
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
  function depositERC20(uint32 poolId, address asset, uint256 amount) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      amount = msg.value;
      VaultLogic.wrapNativeTokenInWallet(asset, msg.sender, amount);
    }

    SupplyLogic.executeDepositERC20(
      InputTypes.ExecuteDepositERC20Params({poolId: poolId, asset: asset, amount: amount})
    );
  }

  function withdrawERC20(uint32 poolId, address asset, uint256 amount) public whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    bool isNative;
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      isNative = true;
      asset = ps.wrappedNativeToken;
    }

    SupplyLogic.executeWithdrawERC20(
      InputTypes.ExecuteWithdrawERC20Params({poolId: poolId, asset: asset, amount: amount})
    );

    if (isNative) {
      VaultLogic.unwrapNativeTokenInWallet(asset, msg.sender, amount);
    }
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
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    bool isNative;
    if (asset == address(Constants.NATIVE_TOKEN_ADDRESS)) {
      isNative = true;
      asset = ps.wrappedNativeToken;
    }

    uint256 totalBorrowAmount = BorrowLogic.executeCrossBorrowERC20(
      InputTypes.ExecuteCrossBorrowERC20Params({poolId: poolId, asset: asset, groups: groups, amounts: amounts})
    );

    if (isNative) {
      VaultLogic.unwrapNativeTokenInWallet(asset, msg.sender, totalBorrowAmount);
    }
  }

  function crossRepayERC20(
    uint32 poolId,
    address asset,
    uint8[] calldata groups,
    uint256[] calldata amounts
  ) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msg.sender, msg.value);
    }

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
  ) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (debtAsset == Constants.NATIVE_TOKEN_ADDRESS) {
      debtAsset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(debtAsset, msg.sender, msg.value);
    }

    bool isCollateralNative;
    if (collateralAsset == Constants.NATIVE_TOKEN_ADDRESS) {
      isCollateralNative = true;
      collateralAsset = ps.wrappedNativeToken;
    }

    (uint256 actualCollateralToLiquidate, ) = LiquidationLogic.executeCrossLiquidateERC20(
      InputTypes.ExecuteCrossLiquidateERC20Params({
        poolId: poolId,
        user: user,
        collateralAsset: collateralAsset,
        debtAsset: debtAsset,
        debtToCover: debtToCover,
        supplyAsCollateral: supplyAsCollateral
      })
    );

    if (isCollateralNative && !supplyAsCollateral) {
      VaultLogic.unwrapNativeTokenInWallet(collateralAsset, msg.sender, actualCollateralToLiquidate);
    }
  }

  function crossLiquidateERC721(
    uint32 poolId,
    address user,
    address collateralAsset,
    uint256[] calldata collateralTokenIds,
    address debtAsset,
    bool supplyAsCollateral
  ) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (debtAsset == Constants.NATIVE_TOKEN_ADDRESS) {
      debtAsset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(debtAsset, msg.sender, msg.value);
    }

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
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    bool isNative;
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      isNative = true;
      asset = ps.wrappedNativeToken;
    }

    uint256 totalBorrowAmount = IsolateLogic.executeIsolateBorrow(
      InputTypes.ExecuteIsolateBorrowParams({
        poolId: poolId,
        nftAsset: nftAsset,
        nftTokenIds: nftTokenIds,
        asset: asset,
        amounts: amounts
      })
    );

    if (isNative) {
      VaultLogic.unwrapNativeTokenInWallet(asset, msg.sender, totalBorrowAmount);
    }
  }

  function isolateRepay(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts
  ) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msg.sender, msg.value);
    }

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
  ) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msg.sender, msg.value);
    }

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
    address asset,
    uint256[] calldata /*amounts*/
  ) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msg.sender, msg.value);
    }

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
    uint256[] calldata /*amounts*/,
    bool supplyAsCollateral
  ) public payable whenNotPaused nonReentrant {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    if (asset == Constants.NATIVE_TOKEN_ADDRESS) {
      asset = ps.wrappedNativeToken;
      VaultLogic.wrapNativeTokenInWallet(asset, msg.sender, msg.value);
    }

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

  function yieldSetERC721TokenData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId,
    bool isLock,
    address debtAsset
  ) public whenNotPaused nonReentrant {
    YieldLogic.executeYieldSetERC721TokenData(
      InputTypes.ExecuteYieldSetERC721TokenDataParams({
        poolId: poolId,
        nftAsset: nftAsset,
        tokenId: tokenId,
        isLock: isLock,
        debtAsset: debtAsset,
        isExternalCaller: true
      })
    );
  }

  /****************************************************************************/
  /* Misc Features */
  /****************************************************************************/
  function flashLoanERC721(
    uint32 poolId,
    address[] calldata nftAssets,
    uint256[] calldata nftTokenIds,
    address receiverAddress,
    bytes calldata params
  ) public whenNotPaused nonReentrant {
    FlashLoanLogic.executeFlashLoanERC721(
      InputTypes.ExecuteFlashLoanERC721Params({
        poolId: poolId,
        nftAssets: nftAssets,
        nftTokenIds: nftTokenIds,
        receiverAddress: receiverAddress,
        params: params
      })
    );
  }

  function collectFeeToTreasury(uint32 poolId, address[] calldata assets) public whenNotPaused nonReentrant {
    PoolLogic.executeCollectFeeToTreasury(poolId, assets);
  }

  /****************************************************************************/
  /* Pool Query */
  /****************************************************************************/
  function getPoolMaxAssetNumber() public pure returns (uint256) {
    return QueryLogic.getPoolMaxAssetNumber();
  }

  function getPoolMaxGroupNumber() public pure returns (uint256) {
    return QueryLogic.getPoolMaxGroupNumber();
  }

  function getPoolName(uint32 poolId) public view returns (string memory) {
    return QueryLogic.getPoolName(poolId);
  }

  function getPoolConfigFlag(
    uint32 poolId
  ) public view returns (bool isPaused, bool isYieldEnabled, bool isYieldPaused, uint8 yieldGroup) {
    return QueryLogic.getPoolConfigFlag(poolId);
  }

  function getPoolGroupList(uint32 poolId) public view returns (uint256[] memory) {
    return QueryLogic.getPoolGroupList(poolId);
  }

  function getPoolAssetList(uint32 poolId) public view returns (address[] memory) {
    return QueryLogic.getPoolAssetList(poolId);
  }

  function getAssetGroupList(uint32 poolId, address asset) public view returns (uint256[] memory) {
    return QueryLogic.getAssetGroupList(poolId, asset);
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
    return QueryLogic.getAssetConfigFlag(poolId, asset);
  }

  function getAssetConfigCap(
    uint32 poolId,
    address asset
  ) public view returns (uint256 supplyCap, uint256 borrowCap, uint256 yieldCap) {
    return QueryLogic.getAssetConfigCap(poolId, asset);
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
    return QueryLogic.getAssetLendingConfig(poolId, asset);
  }

  function getAssetAuctionConfig(
    uint32 poolId,
    address asset
  )
    public
    view
    returns (uint16 redeemThreshold, uint16 bidFineFactor, uint16 minBidFineFactor, uint40 auctionDuration)
  {
    return QueryLogic.getAssetAuctionConfig(poolId, asset);
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
    return QueryLogic.getAssetSupplyData(poolId, asset);
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
    return QueryLogic.getAssetGroupData(poolId, asset, group);
  }

  function getAssetFeeData(
    uint32 poolId,
    address asset
  ) public view returns (uint256 feeFactor, uint256 accruedFee, uint256 normAccruedFee) {
    return QueryLogic.getAssetFeeData(poolId, asset);
  }

  function getUserAccountData(
    address user,
    uint32 poolId
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
    return QueryLogic.getUserAccountData(user, poolId);
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
    return QueryLogic.getUserAssetData(user, poolId, asset);
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
    return QueryLogic.getUserAssetScaledData(user, poolId, asset);
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
    return QueryLogic.getUserAssetGroupData(user, poolId, asset, groupId);
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
    return QueryLogic.getUserAccountDebtData(user, poolId);
  }

  function getIsolateCollateralData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId,
    address debtAsset
  ) public view returns (uint256 totalCollateral, uint256 totalBorrow, uint256 availableBorrow, uint256 healthFactor) {
    return QueryLogic.getIsolateCollateralData(poolId, nftAsset, tokenId, debtAsset);
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
    return QueryLogic.getIsolateLoanData(poolId, nftAsset, tokenId);
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
    return QueryLogic.getIsolateAuctionData(poolId, nftAsset, tokenId);
  }

  function getYieldERC20BorrowBalance(uint32 poolId, address asset, address staker) public view returns (uint256) {
    return QueryLogic.getYieldERC20BorrowBalance(poolId, asset, staker);
  }

  function getERC721TokenData(
    uint32 poolId,
    address asset,
    uint256 tokenId
  ) public view returns (address, uint8, address) {
    return QueryLogic.getERC721TokenData(poolId, asset, tokenId);
  }

  // Pool Admin
  /**
   * @dev Pauses or unpauses the whole protocol.
   */
  function setGlobalPause(bool paused) public {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();

    PoolLogic.checkCallerIsEmergencyAdmin(ps);

    if (paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  function getGlobalPause() public view returns (bool) {
    return paused();
  }

  /**
   * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
   */
  receive() external payable {
    DataTypes.PoolStorage storage ps = StorageSlot.getPoolStorage();
    require(msg.sender == ps.wrappedNativeToken, 'Receive not allowed');
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert('Fallback not allowed');
  }
}
