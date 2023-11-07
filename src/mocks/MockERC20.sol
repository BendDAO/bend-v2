// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20, Ownable {
  uint8 private _decimals;
  bool private _isPublicMint;

  constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
    _decimals = decimals_;
  }

  function mint(uint256 amount) public {
    require(_isPublicMint || msg.sender == owner(), 'invalid caller');

    _mint(msg.sender, amount);
  }

  function mintTo(address to, uint256 amount) public {
    require(msg.sender == owner(), 'invalid caller');

    _mint(to, amount);
  }

  function burn(uint256 amount) public {
    _burn(msg.sender, amount);
  }

  function setIsPublicMint(bool isPublicMint_) public onlyOwner {
    _isPublicMint = isPublicMint_;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }
}
