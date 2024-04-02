// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IStETH, IERC20Metadata} from 'src/interfaces/IStETH.sol';

contract MockStETH is IStETH, ERC20, Ownable2Step {
  uint8 private _decimals;

  constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
    _decimals = decimals_;
  }

  function submit(address /*_referral*/) public payable returns (uint256) {
    require(msg.value > 0, 'msg value is 0');
    _mint(msg.sender, msg.value);
    return msg.value;
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == owner(), 'MockERC20: caller not owner');
    _mint(to, amount);
  }

  function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
    return _decimals;
  }

  function transferETH(address to) public onlyOwner {
    (bool success, ) = to.call{value: address(this).balance}('');
    require(success, 'send value failed');
  }
}
