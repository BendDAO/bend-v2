// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

import {AggregatorV2V3Interface} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol';
import {IBendNFTOracle} from './interfaces/IBendNFTOracle.sol';

import {IACLManager} from './interfaces/IACLManager.sol';
import {IPriceOracle} from './interfaces/IPriceOracle.sol';
import {Constants} from './libraries/helpers/Constants.sol';
import {Errors} from './libraries/helpers/Errors.sol';
import {Events} from './libraries/helpers/Events.sol';

contract PriceOracle is IPriceOracle, Initializable {
  IACLManager public aclManager;

  address public BASE_CURRENCY;
  uint256 public BASE_CURRENCY_UNIT;

  address public NFT_BASE_CURRENCY;
  uint256 public NFT_BASE_CURRENCY_UNIT;

  // BendDAO Protocol NFT Oracle which used by both v1 and v2
  IBendNFTOracle public bendNFTOracle;

  // Chainlink Aggregators for ERC20 tokens
  mapping(address => AggregatorV2V3Interface) public assetChainlinkAggregators;

  modifier onlyOracleAdmin() {
    _onlyOracleAdmin();
    _;
  }

  function _onlyOracleAdmin() internal view {
    require(aclManager.isOracleAdmin(msg.sender), Errors.CALLER_NOT_ORACLE_ADMIN);
  }

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev The ACL admin should be initialized at the addressesProvider beforehand
   */
  function initialize(
    address aclManager_,
    address baseCurrency_,
    uint256 baseCurrencyUnit_,
    address nftBaseCurrency_,
    uint256 nftBaseCurrencyUnit_
  ) public initializer {
    require(aclManager_ != address(0), Errors.ACL_MANAGER_CANNOT_BE_ZERO);
    aclManager = IACLManager(aclManager_);

    // if use US Dollars, baseCurrency will be 0 and unit is 1e8
    BASE_CURRENCY = baseCurrency_;
    BASE_CURRENCY_UNIT = baseCurrencyUnit_;

    NFT_BASE_CURRENCY = nftBaseCurrency_;
    NFT_BASE_CURRENCY_UNIT = nftBaseCurrencyUnit_;
  }

  /// @notice Set Chainlink aggregators for sssets
  function setAssetChainlinkAggregators(
    address[] calldata assets,
    address[] calldata aggregators
  ) public onlyOracleAdmin {
    require(assets.length == aggregators.length, Errors.INCONSISTENT_PARAMS_LENGTH);
    for (uint256 i = 0; i < assets.length; i++) {
      require(assets[i] != address(0), Errors.INVALID_ADDRESS);
      require(aggregators[i] != address(0), Errors.INVALID_ADDRESS);
      assetChainlinkAggregators[assets[i]] = AggregatorV2V3Interface(aggregators[i]);
      emit Events.AssetAggregatorUpdated(assets[i], aggregators[i]);
    }
  }

  function getAssetChainlinkAggregators(address[] calldata assets) public view returns (address[] memory aggregators) {
    aggregators = new address[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      aggregators[i] = address(assetChainlinkAggregators[assets[i]]);
    }
  }

  /// @notice Set the global BendDAO NFT Oracle
  function setBendNFTOracle(address bendNFTOracle_) public onlyOracleAdmin {
    require(bendNFTOracle_ != address(0), Errors.INVALID_ADDRESS);
    bendNFTOracle = IBendNFTOracle(bendNFTOracle_);
    emit Events.BendNFTOracleUpdated(bendNFTOracle_);
  }

  function getBendNFTOracle() public view returns (address) {
    return address(bendNFTOracle);
  }

  /// @notice Query the price of asset
  function getAssetPrice(address asset) external view returns (uint256) {
    if (asset == BASE_CURRENCY) {
      return BASE_CURRENCY_UNIT;
    }

    if (assetChainlinkAggregators[asset] != AggregatorV2V3Interface(address(0))) {
      return getAssetPriceFromChainlink(asset);
    }

    return getAssetPriceFromBendNFTOracle(asset);
  }

  /// @notice Query the price of asset from chainlink oracle
  function getAssetPriceFromChainlink(address asset) public view returns (uint256) {
    uint256 price;

    AggregatorV2V3Interface sourceAgg = assetChainlinkAggregators[asset];
    require(address(sourceAgg) != address(0), Errors.ASSET_AGGREGATOR_NOT_EXIST);

    int256 priceFromAgg = sourceAgg.latestAnswer();
    price = uint256(priceFromAgg);

    require(price > 0, Errors.ASSET_PRICE_IS_ZERO);
    return price;
  }

  /// @notice Query the price of asset from benddao nft oracle
  function getAssetPriceFromBendNFTOracle(address asset) public view returns (uint256) {
    uint256 nftPriceInNftBase = bendNFTOracle.getAssetPrice(asset);
    require(nftPriceInNftBase > 0, Errors.ASSET_PRICE_IS_ZERO);

    // nft oracle use the same currency with protocol
    if (NFT_BASE_CURRENCY == BASE_CURRENCY) {
      return nftPriceInNftBase;
    }

    // convert nft price to base currency, e.g. from ETH to USD
    uint256 nftBaseCurrencyPriceInBase = getAssetPriceFromChainlink(NFT_BASE_CURRENCY);
    uint256 nftPriceInBase = (nftPriceInNftBase * nftBaseCurrencyPriceInBase) / NFT_BASE_CURRENCY_UNIT;
    return nftPriceInBase;
  }
}
