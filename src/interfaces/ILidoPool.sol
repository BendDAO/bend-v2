// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IUnsetETH} from "./IUnsetETH.sol";

interface ILidoPool {
    function stake(address _nft, uint256 _tokenId, uint256 _borrowAmount) external;

    function repay(address _nft, uint256 _tokenId, uint256 _repayAmount) external payable;

    function unstake(address _nft, uint256 _tokenId) external;

    function withdrawNFT(address _nft, uint256 _tokenId, uint256 _repayAmount) external payable;

    function getHF(address _nft, uint256 _tokenId) external returns (uint256);
}
