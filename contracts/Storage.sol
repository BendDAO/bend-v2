// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

abstract contract Storage {
  struct Pool {
    uint256 id; // pool id
    mapping(uint256 => Group) groupLookup;
    uint256[] groupList;
    mapping(address => Asset) assetLookup;
    address[] assetList;
  }

  struct Group {
    uint256 id; // group id
    uint256 totalBorrowed;
    mapping(address => uint256) userBorrowed;
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
    address rateModel;
    uint256 totalCrossSupplied; // total supplied balance in cross margin mode
    mapping(address => uint256) userCrossSupplied; // user supplied balance in cross margin mode
    uint256 totalIsolateSupplied; // total supplied balance in isolate mode, only for ERC721
    mapping(address => uint256) userIsolateSupplied; // user supplied balance in isolate mode, only for ERC721
    mapping(uint256 => ERC721TokenData) erc721TokenData; // token -> data, only for ERC721
    uint256 supplyRate;
    uint256 supplyIndex;
    uint256 accruedFee;
  }

  mapping(uint256 => Pool) poolLookup;
}
