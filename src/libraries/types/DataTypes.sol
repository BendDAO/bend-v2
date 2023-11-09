// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

library DataTypes {
  /****************************************************************************/
  /* Data Types for Common */

  struct CommonStorage {
    address nativeWrappedToken; // WETH
    address aclManager; // ACLManager
    address priceOracle; // PriceOracle
  }

  /****************************************************************************/
  /* Data Types for Pool Lending */
  struct PoolData {
    uint256 poolId;
    address governanceAdmin;

    // underlying asset to asset data
    mapping(address => AssetData) assetLookup;
    address[] assetList;
    // nft address -> nft id -> isolate loan
    mapping(address => mapping(uint256 => IsolateLoanData)) loanLookup;
    // account data
    mapping(address => AccountData) accountLookup;
  }

  struct AccountData {
    EnumerableSetUpgradeable.AddressSet suppliedAssets;
    EnumerableSetUpgradeable.AddressSet borrowedAssets;
  }

  struct GroupData {
    // config parameters
    address interestRateModelAddress;
    // user debt state
    uint256 totalCrossBorrowed;
    mapping(address => uint256) userCrossBorrowed;
    uint256 totalIsolateBorrowed;
    // group debt state
    uint128 borrowRate;
    uint128 borrowIndex;
    uint40 lastUpdateTimestamp;
  }

  struct ERC721TokenData {
    address owner;
    uint8 supplyMode; // 0=cross margin, 1=isolate
  }

  struct AssetData {
    // config params
    uint8 assetType; // ERC20=0, ERC721=1
    uint8 underlyingDecimals; // only for ERC20
    uint8 riskGroupId; //risk group id
    bool isActive;
    bool isFrozen;
    bool isPaused;
    bool isBorrowingEnabled;
    uint32 supplyCap;
    uint32 borrowCap;
    uint16 feeFactor;
    uint16 collateralFactor;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    // group state
    uint8 nextGroupId;
    mapping(uint8 => GroupData) groupLookup;
    uint8[] groupList;
    // user state
    uint256 totalCrossSupplied; // total supplied balance in cross margin mode
    mapping(address => uint256) userCrossSupplied; // user supplied balance in cross margin mode
    uint256 totalIsolateSupplied; // total supplied balance in isolate mode, only for ERC721
    mapping(address => uint256) userIsolateSupplied; // user supplied balance in isolate mode, only for ERC721
    mapping(uint256 => ERC721TokenData) erc721TokenData; // token -> data, only for ERC721
    // asset interest state
    uint128 supplyRate;
    uint128 supplyIndex;
    uint256 accruedFee;
    uint40 lastUpdateTimestamp;
  }

  struct IsolateLoanData {
    address reserveAsset;
    uint256 reserveAmount;
    uint256 loanStatus; // 0=init, 1=active, 2=repaid, 3=auction, 4=liquidated
    uint256 debtGroupId;
  }

  struct PoolLendingStorage {
    uint32 nextPoolId;
    mapping(uint32 => PoolData) poolLookup;
  }

  /****************************************************************************/
  /* Data Types for Pool Yield */

  struct PoolYieldStorage {
    uint256 reserve;
  }

  /****************************************************************************/
  /* Data Types for P2P Lending */

  struct P2PLendingStorage {
    uint256 reserve;
  }
}
