// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IeETH} from 'src/yield/etherfi/IeETH.sol';
import {ILiquidityPool} from 'src/yield/etherfi/ILiquidityPool.sol';
import {IWithdrawRequestNFT} from 'src/yield/etherfi/IWithdrawRequestNFT.sol';

import {MockeETH} from './MockeETH.sol';

contract MockEtherfiLiquidityPool is ILiquidityPool, Ownable2Step {
  uint256 private constant RAY = 10 ** 27;

  address public override eETH;
  address public override withdrawRequestNFT;
  uint256 public shareRatio;

  constructor(address _eETH, address _withdrawRequestNFT) {
    eETH = _eETH;
    withdrawRequestNFT = _withdrawRequestNFT;
    shareRatio = (RAY * 1000) / 965; // 3.5% APR
  }

  function setShareRatio(uint256 shareRatio_) public onlyOwner {
    shareRatio = shareRatio_;
  }

  function getShareRatio() public view returns (uint256) {
    return shareRatio;
  }

  function deposit() external payable override returns (uint256) {
    require(msg.value > 0, 'msg value is 0');

    uint256 share = sharesForAmount(msg.value);
    MockeETH(payable(eETH)).mintShare(msg.sender, share);
    return share;
  }

  function rebase(address to) public payable returns (uint256) {
    require(msg.value > 0, 'msg value is 0');

    uint256 share = sharesForAmount(msg.value);
    MockeETH(payable(eETH)).mintShare(to, share);
    return share;
  }

  function requestWithdraw(address recipient, uint256 amount) external override returns (uint256) {
    uint256 share = sharesForAmount(amount);

    IeETH(payable(eETH)).transferFrom(msg.sender, address(withdrawRequestNFT), share);

    uint256 requestId = IWithdrawRequestNFT(withdrawRequestNFT).requestWithdraw(
      uint96(amount),
      uint96(share),
      recipient,
      0
    );
    return requestId;
  }

  function withdraw(address _recipient, uint256 _amount) external override returns (uint256) {
    require(msg.sender == address(withdrawRequestNFT), 'Incorrect Caller');

    uint256 share = sharesForAmount(_amount);
    MockeETH(payable(eETH)).burnShare(msg.sender, share);

    _sendFund(_recipient, _amount);

    return _amount;
  }

  function amountForShare(uint256 _share) public view returns (uint256) {
    return (_share * shareRatio) / RAY;
  }

  function sharesForAmount(uint256 _amount) public view returns (uint256) {
    return (_amount * RAY) / shareRatio;
  }

  function transferETH(address to) public onlyOwner {
    (bool success, ) = to.call{value: address(this).balance}('');
    require(success, 'send value failed');
  }

  function setEETH(address _eETH, address _withdrawRequestNFT) public onlyOwner {
    eETH = _eETH;
    withdrawRequestNFT = _withdrawRequestNFT;
  }

  function _sendFund(address _recipient, uint256 _amount) internal {
    uint256 balanace = address(this).balance;
    (bool sent, ) = _recipient.call{value: _amount}('');
    require(sent && address(this).balance == balanace - _amount, 'SendFail');
  }

  receive() external payable {}
}
