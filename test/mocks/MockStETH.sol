// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IStETH, IERC20Metadata} from 'src/interfaces/IStETH.sol';

contract MockStETH is IStETH, ERC20, Ownable2Step {
  uint256 private constant RAY = 10 ** 27;

  uint8 private _decimals;
  address private _unstETH;
  uint256 public shareRatio;

  constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
    _decimals = decimals_;
    shareRatio = (RAY * 1000) / 963; // 3.7% APR
  }

  function setShareRatio(uint256 shareRatio_) public onlyOwner {
    shareRatio = shareRatio_;
  }

  function getShareRatio() public view returns (uint256) {
    return shareRatio;
  }

  function submit(address /*_referral*/) public payable returns (uint256) {
    require(msg.value > 0, 'msg value is 0');

    if (_unstETH != address(0)) {
      _transferETH(_unstETH);
    }

    uint256 share = getSharesByPooledEth(msg.value);

    _mint(msg.sender, share);
    return share;
  }

  function rebase(address to) public payable returns (uint256) {
    require(msg.value > 0, 'msg value is 0');

    if (_unstETH != address(0)) {
      _transferETH(_unstETH);
    }

    uint256 share = getSharesByPooledEth(msg.value);

    _mint(to, share);
    return share;
  }

  function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
    return _decimals;
  }

  function balanceOf(address _user) public view override(ERC20, IERC20) returns (uint256) {
    return getPooledEthByShares(sharesOf(_user));
  }

  function sharesOf(address _user) public view returns (uint256) {
    return super.balanceOf(_user);
  }

  function getSharesByPooledEth(uint256 _ethAmount) public view returns (uint256) {
    return (_ethAmount * RAY) / shareRatio;
  }

  function getPooledEthByShares(uint256 _sharesAmount) public view returns (uint256) {
    return (_sharesAmount * shareRatio) / RAY;
  }

  function transferETH(address to) public onlyOwner {
    _transferETH(to);
  }

  function setUnstETH(address unstETH_) public onlyOwner {
    _unstETH = unstETH_;
  }

  function _transferETH(address to) internal {
    (bool success, ) = to.call{value: address(this).balance}('');
    require(success, 'send value failed');
  }

  receive() external payable {}
}
