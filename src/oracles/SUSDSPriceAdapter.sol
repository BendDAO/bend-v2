// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AggregatorV2V3Interface} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol';

import {IUSDSRate} from './IUSDSRate.sol';

/**
 * @title SUSDSPriceAdapter
 * @notice Price adapter to calculate price of sUSDS pair by using
 * @notice Chainlink Data Feed for USDS and rate provider for sUSDS.
 */
contract SUSDSPriceAdapter {
  /**
   * @notice Price feed for USDS pair
   */
  AggregatorV2V3Interface public immutable USDS_AGGREGATOR;

  /**
   * @notice rate provider for (sUSDS / USDS)
   */
  IUSDSRate public immutable RATE_PROVIDER;

  /**
   * @notice Number of decimals for sUSDS / USDS ratio
   */
  uint8 public constant RATIO_DECIMALS = 27;

  /**
   * @notice Number of decimals in the output of this price adapter
   */
  uint8 public immutable DECIMALS;

  string private _description;

  /**
   * @param usdsAggregatorAddress the address of USDS feed
   * @param rateProviderAddress the address of the rate provider
   * @param pairName the name identifier of sUSDS paire
   */
  constructor(address usdsAggregatorAddress, address rateProviderAddress, string memory pairName) {
    USDS_AGGREGATOR = AggregatorV2V3Interface(usdsAggregatorAddress);
    RATE_PROVIDER = IUSDSRate(rateProviderAddress);

    DECIMALS = USDS_AGGREGATOR.decimals();

    _description = pairName;
  }

  function description() public view returns (string memory) {
    return _description;
  }

  function decimals() public view returns (uint8) {
    return DECIMALS;
  }

  function version() public view returns (uint256) {
    return USDS_AGGREGATOR.version();
  }

  function latestAnswer() public view virtual returns (int256) {
    int256 usdsPrice = USDS_AGGREGATOR.latestAnswer();
    return _convertUSDSPrice(usdsPrice);
  }

  function latestTimestamp() public view returns (uint256) {
    return USDS_AGGREGATOR.latestTimestamp();
  }

  function latestRound() public view returns (uint256) {
    return USDS_AGGREGATOR.latestRound();
  }

  function getAnswer(uint256 roundId) public view returns (int256) {
    int256 usdsPrice = USDS_AGGREGATOR.getAnswer(roundId);
    int256 susdsPrice = _convertUSDSPrice(usdsPrice);
    return susdsPrice;
  }

  function getTimestamp(uint256 roundId) public view returns (uint256) {
    return USDS_AGGREGATOR.getTimestamp(roundId);
  }

  function latestRoundData()
    public
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    (
      uint80 roundId_,
      int256 usdsPrice,
      uint256 startedAt_,
      uint256 updatedAt_,
      uint80 answeredInRound_
    ) = USDS_AGGREGATOR.latestRoundData();

    int256 susdsPrice = _convertUSDSPrice(usdsPrice);

    return (roundId_, susdsPrice, startedAt_, updatedAt_, answeredInRound_);
  }

  function getRoundData(
    uint80 _roundId
  ) public view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
    (
      uint80 roundId_,
      int256 usdsPrice,
      uint256 startedAt_,
      uint256 updatedAt_,
      uint80 answeredInRound_
    ) = USDS_AGGREGATOR.getRoundData(_roundId);

    int256 susdsPrice = _convertUSDSPrice(usdsPrice);

    return (roundId_, susdsPrice, startedAt_, updatedAt_, answeredInRound_);
  }

  function _convertUSDSPrice(int256 usdsPrice) internal view returns (int256) {
    int256 ratio = int256(RATE_PROVIDER.chi());

    if (usdsPrice <= 0 || ratio <= 0) {
      return 0;
    }

    return (usdsPrice * ratio) / int256(10 ** RATIO_DECIMALS);
  }
}
