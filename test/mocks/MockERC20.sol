// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20, Ownable2Step {
  uint8 private _decimals;

  constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
    _decimals = decimals_;
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == owner(), 'MockERC20: caller not owner');
    _mint(to, amount);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }
}
