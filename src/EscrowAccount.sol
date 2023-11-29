// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC721Holder} from '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';

contract EscrowAccount is ERC721Holder {
  using SafeERC20 for IERC20;

  address private _owner;

  constructor(address owner_) {
    _owner = owner_;
  }

  /**
   * @dev Transfers erc20 to the target user
   */
  function transferERC20(address token, address to, uint256 amount) public {
    require(_owner == msg.sender, 'caller not owner');

    IERC20(token).safeTransferFrom(address(this), to, amount);
  }

  /**
   * @dev Transfers single erc721 to the target user
   */
  function transferERC721(address token, address to, uint256 tokenId) public {
    require(_owner == msg.sender, 'caller not owner');

    IERC721(token).safeTransferFrom(address(this), to, tokenId);
  }

  /**
   * @dev Batch transfers multiple erc721 to the target user
   */
  function batchTransferERC721(address token, address to, uint256[] calldata tokenIds) public {
    require(_owner == msg.sender, 'caller not owner');

    for (uint256 i = 0; i < tokenIds.length; i++) {
      IERC721(token).safeTransferFrom(address(this), to, tokenIds[i]);
    }
  }
}
