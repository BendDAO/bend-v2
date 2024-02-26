// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

import {IPoolManager} from "../../interfaces/IPoolManager.sol";
import {IStETH} from "../../interfaces/IStETH.sol";
import {IWstETH} from "../../interfaces/IWstETH.sol";
import {IUnsetETH} from "../../interfaces/IUnsetETH.sol";
import {IWETH} from "../../interfaces/IWETH.sol";
import {IPriceOracleGetter} from "../../interfaces/IPriceOracleGetter.sol";

library DataTypes {

  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

  /****************************************************************************/
  /* Data Types for lido staking */
  struct StakePoolStorage {
      IPoolManager poolManager;
      IStETH stETH;
      IWstETH wstETH;
      IUnsetETH unsetETH;
      IWETH wETH;
      IPriceOracleGetter priceOracle;
      address bot;
      uint32 poolId;
      mapping(address => NftConfig) nftConfigs;
      // nft => token_id => stakeDetail
      mapping(address => mapping(uint256 => StakeDetail)) stakeDetails;
      // user => nft => token_ids
      mapping(address => mapping(address => EnumerableSetUpgradeable.UintSet)) stakedTokens;
      // user => requests
      mapping(address => EnumerableSetUpgradeable.UintSet) withdrawRequestIds;
      uint256 fines;
      uint256 totalYieldShare;
      uint256 totalDebtShare;
  }

  enum StakeState {
      None,
      Active,
      Unstaking
  }

  struct StakeDetail {
      address staker;
      StakeState state;
      address nft;
      uint256 tokenId;
      // wEth debt shares
      uint256 debtShare;
      // stEth shares
      uint256 yieldShare;
      // unstake
      uint256 unstakeFine;
      // repay
      uint256 repayRequestId;
  }

  struct NftConfig {
      bool active;
      uint256 maxUnstakeFine;
      uint256 hfThreshold;
      uint256 unstakeHf; //  eg: unstakeHf = 1.2
  }
  /****************************************************************************/
  /* Data Types for Pool Lending */
  struct PoolData {
    uint32 poolId;
    string name;
    address governanceAdmin;

    // group
    mapping(uint8 => bool) enabledGroups;
    EnumerableSetUpgradeable.UintSet groupList;

    // underlying asset to asset data
    mapping(address => AssetData) assetLookup;
    EnumerableSetUpgradeable.AddressSet assetList;

    // nft address -> nft id -> isolate loan
    mapping(address => mapping(uint256 => IsolateLoanData)) loanLookup;
    // account data
    mapping(address => AccountData) accountLookup;

    // yield
    bool isYieldEnabled;
    bool isYieldPaused;
    uint8 yieldGroup;
  }

  struct AccountData {
    EnumerableSetUpgradeable.AddressSet suppliedAssets;
    EnumerableSetUpgradeable.AddressSet borrowedAssets;
  }

  struct GroupData {
    // config parameters
    address rateModel;

    // user state
    uint256 totalScaledCrossBorrow;
    mapping(address => uint256) userScaledCrossBorrow;
    uint256 totalScaledIsolateBorrow;
    mapping(address => uint256) userScaledIsolateBorrow;

    // interest state
    uint128 borrowRate;
    uint128 borrowIndex;
    uint8 groupId;
  }

  struct ERC721TokenData {
    address owner;
    uint8 supplyMode; // 0=cross margin, 1=isolate
    uint16 lockFlag;
  }

  struct StakerData {
    uint256 yieldCap;
  }

  struct AssetData {
    // config params
    address underlyingAsset;
    uint8 assetType; // ERC20=0, ERC721=1
    uint8 underlyingDecimals; // only for ERC20
    uint8 classGroup;
    bool isActive;
    bool isFrozen;
    bool isPaused;
    bool isBorrowingEnabled;
    bool isFlashLoanEnabled;
    bool isYieldEnabled;
    bool isYieldPaused;
    uint16 feeFactor;
    uint16 collateralFactor;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    uint16 redeemThreshold;
    uint16 bidFineFactor;
    uint16 minBidFineFactor;
    uint40 auctionDuration;
    uint256 supplyCap;
    uint256 borrowCap;
    uint256 yieldCap;

    // group state
    mapping(uint8 => GroupData) groupLookup;
    EnumerableSetUpgradeable.UintSet groupList;

    // user state
    uint256 totalScaledCrossSupply; // total supplied balance in cross margin mode
    uint256 totalScaledIsolateSupply; // total supplied balance in isolate mode, only for ERC721
    uint256 availableLiquidity;
    uint256 totalBidAmout;
    mapping(address => uint256) userScaledCrossSupply; // user supplied balance in cross margin mode
    mapping(address => uint256) userScaledIsolateSupply; // user supplied balance in isolate mode, only for ERC721
    mapping(uint256 => ERC721TokenData) erc721TokenData; // token -> data, only for ERC721

    // asset interest state
    uint128 supplyRate;
    uint128 supplyIndex;
    uint256 accruedFee;
    uint40 lastUpdateTimestamp;

    // yield state
    mapping(address => StakerData) stakerLookup;
  }

  struct IsolateLoanData {
    address reserveAsset;
    uint256 scaledAmount;
    uint8 reserveGroup;
    uint8 loanStatus;
    uint40 bidStartTimestamp;
    address firstBidder;
    address lastBidder;
    uint256 bidAmount;
  }

  /****************************************************************************/
  /* Data Types for Storage */
  struct PoolStorage {
    // common fileds
    address nativeWrappedToken; // WETH
    address aclManager; // ACLManager
    address priceOracle; // PriceOracle

    // pool fields
    uint32 nextPoolId;
    mapping(uint32 => PoolData) poolLookup;

    // yield fields
  }

}
