// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

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
    // group data
    uint256 nextGroupId;
    mapping(uint256 => GroupData) groupLookup;
    uint256[] groupList;
    // underlying asset to asset data
    mapping(address => AssetData) assetLookup;
    address[] assetList;
    // nft address -> nft id -> isolate loan
    mapping(address => mapping(uint256 => IsolateLoanData)) loanLookup;
  }

  struct GroupData {
    uint256 totalCrossBorrowed;
    mapping(address => uint256) userCrossBorrowed;
    uint256 totalIsolateBorrowed;
    address interestRateModelAddress;
    uint128 borrowRate;
    uint128 borrowIndex;
  }

  struct ERC721TokenData {
    address owner;
    uint8 supplyMode; // 0=cross margin, 1=isolate
  }

  struct AssetData {
    uint256 groupId; // group id
    uint256 assetType; // ERC20=0, ERC721=1
    uint32 collateralFactor;
    uint32 liquidationFactor;
    uint32 feeFactor;
    uint256 totalCrossSupplied; // total supplied balance in cross margin mode
    mapping(address => uint256) userCrossSupplied; // user supplied balance in cross margin mode
    uint256 totalIsolateSupplied; // total supplied balance in isolate mode, only for ERC721
    mapping(address => uint256) userIsolateSupplied; // user supplied balance in isolate mode, only for ERC721
    mapping(uint256 => ERC721TokenData) erc721TokenData; // token -> data, only for ERC721
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
    uint256 nextPoolId;
    mapping(uint256 => PoolData) poolLookup;
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
