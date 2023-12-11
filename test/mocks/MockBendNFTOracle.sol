// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/interfaces/IBendNFTOracle.sol';

contract MockBendNFTOracle is IBendNFTOracle {
  mapping(address => uint256) public prices;

  function getAssetPrice(address _nftContract) public view returns (uint256 price) {
    require(_nftContract != address(0), '_nftContract zero');

    price = prices[_nftContract];
    require(price > 0, 'price zero');
  }

  function setAssetPrice(address _nftContract, uint256 price) public {
    require(_nftContract != address(0), '_nftContract zero');
    require(price > 0, 'price zero');

    prices[_nftContract] = price;
  }
}
