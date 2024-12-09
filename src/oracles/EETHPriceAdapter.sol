// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AggregatorV2V3Interface} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol';

import {IWeETH} from './IWeETH.sol';

/**
 * @title EETHPriceAdapter
 * @notice Price adapter to calculate price of (eETH / USD) pair by using
 * @notice Chainlink data feed for (ETH / USD), (weETH / ETH) and (weETH / eETH) ratio.
 */
contract EETHPriceAdapter {
  uint256 public constant VERSION = 1;

  /**
   * @notice Price feed for ETH / USD pair
   */
  AggregatorV2V3Interface public immutable BASE_AGGREGATOR;

  /**
   * @notice Price feed for weETH / ETH pair
   */
  AggregatorV2V3Interface public immutable WEETH_AGGREGATOR;

  /**
   * @notice rate provider for (weETH / eETH)
   */
  IWeETH public immutable RATE_PROVIDER;

  /**
   * @notice Number of decimals for eETH / eETH ratio
   */
  uint8 public constant RATIO_DECIMALS = 18;

  /**
   * @notice Number of decimals in the output of the base price adapter
   */
  uint8 public immutable BASE_DECIMALS;

  /**
   * @notice Number of decimals in the output of the weETH price adapter
   */
  uint8 public immutable WEETH_DECIMALS;

  string private _description;

  /**
   * @param ethAggAddress the address of ETH feed
   * @param weETHAggAddress the address of ETH feed
   * @param weETHAddress the address of the rate provider
   * @param pairName the name identifier of sDAI paire
   */
  constructor(address ethAggAddress, address weETHAggAddress, address weETHAddress, string memory pairName) {
    BASE_AGGREGATOR = AggregatorV2V3Interface(ethAggAddress);
    WEETH_AGGREGATOR = AggregatorV2V3Interface(weETHAggAddress);
    RATE_PROVIDER = IWeETH(weETHAddress);

    BASE_DECIMALS = BASE_AGGREGATOR.decimals();
    WEETH_DECIMALS = WEETH_AGGREGATOR.decimals();

    _description = pairName;
  }

  function description() public view returns (string memory) {
    return _description;
  }

  function decimals() public view returns (uint8) {
    return BASE_DECIMALS;
  }

  function version() public pure returns (uint256) {
    return VERSION;
  }

  function latestAnswer() public view virtual returns (int256) {
    int256 basePrice = BASE_AGGREGATOR.latestAnswer();
    int256 weETHPrice = WEETH_AGGREGATOR.latestAnswer();

    return _convertWEETHPrice(basePrice, weETHPrice);
  }

  function latestTimestamp() public view returns (uint256) {
    return BASE_AGGREGATOR.latestTimestamp();
  }

  function latestRound() public view returns (uint256) {
    return BASE_AGGREGATOR.latestRound();
  }

  function getAnswer(uint256 roundId) public view returns (int256) {
    int256 basePrice = BASE_AGGREGATOR.getAnswer(roundId);
    int256 weETHPrice = WEETH_AGGREGATOR.latestAnswer();

    return _convertWEETHPrice(basePrice, weETHPrice);
  }

  function getTimestamp(uint256 roundId) public view returns (uint256) {
    return BASE_AGGREGATOR.getTimestamp(roundId);
  }

  function latestRoundData()
    public
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    (
      uint80 roundId_,
      int256 basePrice,
      uint256 startedAt_,
      uint256 updatedAt_,
      uint80 answeredInRound_
    ) = BASE_AGGREGATOR.latestRoundData();
    int256 weETHPrice = WEETH_AGGREGATOR.latestAnswer();

    int256 eETHBasePrice = _convertWEETHPrice(basePrice, weETHPrice);

    return (roundId_, eETHBasePrice, startedAt_, updatedAt_, answeredInRound_);
  }

  function getRoundData(
    uint80 _roundId
  ) public view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
    (
      uint80 roundId_,
      int256 basePrice,
      uint256 startedAt_,
      uint256 updatedAt_,
      uint80 answeredInRound_
    ) = BASE_AGGREGATOR.getRoundData(_roundId);
    int256 weETHPrice = WEETH_AGGREGATOR.latestAnswer();

    int256 eETHBasePrice = _convertWEETHPrice(basePrice, weETHPrice);

    return (roundId_, eETHBasePrice, startedAt_, updatedAt_, answeredInRound_);
  }

  function _convertWEETHPrice(int256 basePrice, int256 weETHPrice) internal view returns (int256) {
    int256 ratio = int256(RATE_PROVIDER.getWeETHByeETH(1 ether));

    if (basePrice <= 0 || weETHPrice <= 0 || ratio <= 0) {
      return 0;
    }

    // calculate the price of the (eETH / ETH) from (weETH / ETH)
    int256 eETHPrice = (weETHPrice * ratio) / int256(10 ** RATIO_DECIMALS);

    // calculate the price of the (eETH / ETH) from (ETH / USD)
    return (basePrice * eETHPrice) / int256(10 ** WEETH_DECIMALS);
  }
}
