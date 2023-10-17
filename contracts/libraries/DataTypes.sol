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
  struct Pool {
    // group data
    uint256 nextGroupId;
    mapping(uint256 => Group) groupLookup;
    uint256[] groupList;
    // underlying asset to asset data
    mapping(address => Asset) assetLookup;
    address[] assetList;
    // nft address -> nft id -> isolate loan
    mapping(address => mapping(uint256 => IsolateLoan)) loanLookup;
  }

  struct Group {
    uint256 totalCrossBorrowed;
    mapping(address => uint256) userCrossBorrowed;
    uint256 totalIsolateBorrowed;
    address rateModel;
    uint256 borrowRate;
    uint256 borrowIndex;
  }

  struct ERC721TokenData {
    address owner;
    uint8 supplyMode; // 0=cross margin, 1=isolate
  }

  struct Asset {
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
    uint256 supplyRate;
    uint256 supplyIndex;
    uint256 accruedFee;
  }

  struct IsolateLoan {
    address reserveAsset;
    uint256 reserveAmount;
    uint256 loanStatus; // 0=init, 1=active, 2=repaid, 3=auction, 4=liquidated
    uint256 debtGroupId;
  }

  struct PoolLendingStorage {
    uint256 nextPoolId;
    mapping(uint256 => Pool) poolLookup;
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
