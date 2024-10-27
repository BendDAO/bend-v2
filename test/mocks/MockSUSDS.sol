// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {ISavingsUSDS, IERC20Metadata} from 'src/yield/susds/ISavingsUSDS.sol';

contract MockSUSDS is ISavingsUSDS, ERC20, Ownable2Step {
  uint256 private constant RAY = 10 ** 27;

  address private _usds;
  uint8 private _decimals;
  uint256 private _ratio;
  // Savings yield
  uint192 private _chi; // The Rate Accumulator  [ray]
  uint64 private _rho; // Time of last drip     [unix epoch time]
  uint256 private _ssr; // The USDS Savings Rate [ray]

  constructor(address usds_) ERC20('Savings USDS', 'sUSDS') {
    _usds = usds_;
    _decimals = 18;
    _ratio = (RAY * 1000) / 925; // 7.5% APR;

    _chi = uint192(RAY);
    _rho = uint64(block.timestamp);
    _ssr = RAY;
  }

  function setShareRatio(uint256 ratio_) public onlyOwner {
    _ratio = ratio_;
  }

  function getShareRatio() public view returns (uint256) {
    return _ratio;
  }

  function usds() public view returns (address) {
    return _usds;
  }

  function setChi(uint192 chi_) public onlyOwner {
    _chi = chi_;
  }

  function chi() public view returns (uint192) {
    return _chi;
  }

  function setRho(uint64 rho_) public onlyOwner {
    _rho = rho_;
  }

  function rho() public view returns (uint64) {
    return _rho;
  }

  function setSsr(uint256 ssr_) public onlyOwner {
    _ssr = ssr_;
  }

  function ssr() public view returns (uint256) {
    return _ssr;
  }

  function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
    ERC20(_usds).transferFrom(msg.sender, address(this), assets);

    shares = convertToShares(assets);
    _mint(receiver, shares);

    return shares;
  }

  function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
    _burn(owner, shares);

    assets = convertToAssets(shares);

    ERC20(_usds).transfer(receiver, assets);

    return assets;
  }

  function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
    shares = convertToShares(assets);
    _burn(owner, shares);

    ERC20(_usds).transfer(receiver, assets);

    return shares;
  }

  function convertToShares(uint256 assets) public view returns (uint256) {
    return (assets * RAY) / _ratio;
  }

  function convertToAssets(uint256 shares) public view returns (uint256) {
    return (shares * _ratio) / RAY;
  }

  function rebase(address receiver, uint256 amount) public returns (uint256) {
    ERC20(_usds).transferFrom(msg.sender, address(this), amount);

    uint256 shares = convertToShares(amount);
    _mint(receiver, shares);

    return shares;
  }

  function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
    return _decimals;
  }

  function transferUSDS(address receiver) public onlyOwner {
    uint256 amount = ERC20(_usds).balanceOf(address(this));
    ERC20(_usds).transfer(receiver, amount);
  }
}
