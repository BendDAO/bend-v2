// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'src/interfaces/IBendNFTOracle.sol';

contract MockBendNFTOracle is IBendNFTOracle {
  uint8 public decimals;
  mapping(address => uint256) public prices;
  mapping(address => uint256) public latestTimestamps;
  mapping(address => uint256) public priceFeedLengths;

  constructor(uint8 decimals_) {
    decimals = decimals_;
  }

  function getAssetPrice(address _nftContract) public view returns (uint256 price) {
    price = prices[_nftContract];
  }

  function setAssetPrice(address _nftContract, uint256 price) public {
    prices[_nftContract] = price;
    latestTimestamps[_nftContract] = block.timestamp;
    priceFeedLengths[_nftContract] += 1;
  }

  function getLatestTimestamp(address _nftContract) public view returns (uint256) {
    return latestTimestamps[_nftContract];
  }

  function getDecimals() external view returns (uint8) {
    return decimals;
  }

  function getPriceFeedLength(address _nftContract) external view returns (uint256 length) {
    return priceFeedLengths[_nftContract];
  }
}
