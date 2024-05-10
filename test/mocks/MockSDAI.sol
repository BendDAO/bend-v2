// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {ISavingsDai, IERC20Metadata} from 'src/yield/sdai/ISavingsDai.sol';

contract MockSDAI is ISavingsDai, ERC20, Ownable2Step {
  uint8 private _decimals;
  address private _dai;

  constructor(address dai_) ERC20('Savings Dai', 'sDAI') {
    _decimals = 18;
    _dai = dai_;
  }

  function dai() public returns (address) {
    return _dai;
  }

  function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
    ERC20(_dai).transferFrom(msg.sender, address(this), assets);

    _mint(receiver, assets);

    return assets;
  }

  function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
    _burn(owner, shares);

    ERC20(_dai).transfer(receiver, shares);

    return shares;
  }

  function convertToShares(uint256 assets) public view returns (uint256) {
    return assets;
  }

  function convertToAssets(uint256 shares) public view returns (uint256) {
    return shares;
  }

  function rebase(address receiver, uint256 amount) public returns (uint256) {
    ERC20(_dai).transferFrom(msg.sender, address(this), amount);

    _mint(receiver, amount);

    return amount;
  }

  function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
    return _decimals;
  }

  function transferDAI(address receiver) public onlyOwner {
    uint256 amount = ERC20(_dai).balanceOf(address(this));
    ERC20(_dai).transfer(receiver, amount);
  }
}
