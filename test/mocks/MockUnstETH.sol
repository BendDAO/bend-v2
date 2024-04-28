// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IStETH} from 'src/interfaces/IStETH.sol';
import {IUnstETH} from 'src/interfaces/IUnstETH.sol';

contract MockUnstETH is IUnstETH, ERC20, Ownable2Step {
  uint8 private _decimals;
  IStETH private _stETH;
  uint256 private _nextRequestId;
  mapping(uint256 => WithdrawalRequestStatus) private _withdrawStatuses;

  constructor(string memory name_, string memory symbol_, uint8 decimals_, address stETH_) ERC20(name_, symbol_) {
    _decimals = decimals_;
    _stETH = IStETH(stETH_);
    _nextRequestId = 1;
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == owner(), 'MockERC20: caller not owner');
    _mint(to, amount);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function requestWithdrawals(
    uint256[] calldata _amounts,
    address _owner
  ) public override returns (uint256[] memory requestIds) {
    requestIds = new uint256[](_amounts.length);

    for (uint i = 0; i < _amounts.length; i++) {
      _stETH.transferFrom(msg.sender, address(this), _amounts[i]);

      requestIds[i] = _nextRequestId++;

      _withdrawStatuses[requestIds[i]].amountOfStETH = _amounts[i];
      _withdrawStatuses[requestIds[i]].amountOfShares = _amounts[i];
      _withdrawStatuses[requestIds[i]].owner = _owner;
      _withdrawStatuses[requestIds[i]].timestamp = block.timestamp;
    }
  }

  function setWithdrawalStatus(uint256 _requestId, bool isFinalized, bool isClaimed) public {
    _withdrawStatuses[_requestId].isFinalized = isFinalized;
    _withdrawStatuses[_requestId].isClaimed = isClaimed;
  }

  function getWithdrawalStatus(
    uint256[] calldata _requestIds
  ) public view override returns (WithdrawalRequestStatus[] memory statuses) {
    statuses = new WithdrawalRequestStatus[](_requestIds.length);
    for (uint i = 0; i < _requestIds.length; i++) {
      statuses[i] = _withdrawStatuses[_requestIds[i]];
    }
  }

  function claimWithdrawal(uint256 _requestId) public override {
    require(_withdrawStatuses[_requestId].owner == msg.sender, 'not owner');
    require(!_withdrawStatuses[_requestId].isClaimed, 'already claimed');

    _withdrawStatuses[_requestId].isClaimed = true;

    (bool success, ) = msg.sender.call{value: _withdrawStatuses[_requestId].amountOfStETH}('');
    require(success, 'send value failed');
  }

  receive() external payable {}
}
