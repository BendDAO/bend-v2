// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {EnumerableSetUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';

import {IPoolManager} from '../../interfaces/IPoolManager.sol';
import {IStETH} from '../../interfaces/IStETH.sol';
import {IUnsetETH} from '../../interfaces/IUnsetETH.sol';
import {IWETH} from '../../interfaces/IWETH.sol';
import {IPriceOracleGetter} from '../../interfaces/IPriceOracleGetter.sol';

import {StorageSlot} from './StorageSlot.sol';
import {DataTypes} from '../types/DataTypes.sol';
import {MathUtils} from '../math/MathUtils.sol';
import {WadRayMath} from '../math/WadRayMath.sol';
import {ShareUtils} from '../math/ShareUtils.sol';
import {PercentageMath} from '../math/PercentageMath.sol';
import {ETHPriceOracle} from '../helpers/ETHPriceOracle.sol';

error NoUnstakeRequestId(address nft, uint256 tokenId);
error DebtUnpaid(address nft, uint256 tokenId);
error NotNftOwner(address nft, uint256 tokenId);
error NotRequestOwner(uint256 requestId);
error LowHealthFactor(address nft, uint256 tokenId, uint256 hf);
error InvalidHealthFactor(address nft, uint256 tokenId, uint256 hf);
error InvalidNft(address nft);
error InvalidFine(uint256 fine);
error NonUnstakeable(address nft, uint256 tokenId);
error NonStakeable(address nft, uint256 tokenId);
error NonRepayable(address nft, uint256 tokenId);
error NonWithdrawable(address nft, uint256 tokenId);
error NonClaimable(uint256 requestId);
error LowUnstakeHF(uint256 hf);

library StakeLogic {
  using ETHPriceOracle for IPriceOracleGetter;
  using PercentageMath for uint256;
  using ShareUtils for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;
  using Math for uint256;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  using SafeERC20 for IWETH;
  using Address for address;

  function totalDebt(uint32 _poolId, IPoolManager _poolManager, IWETH _wETH) private view returns (uint256) {
    return _poolManager.getYieldERC20BorrowBalance(_poolId, address(_wETH), address(this));
  }

  function totalYield(IStETH _stETH) private view returns (uint256) {
    return _stETH.balanceOf(address(this));
  }

  function convertToDebtShares(uint256 assets) private view returns (uint256) {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    return
      assets.convertToShares(
        ss.totalDebtShare,
        totalDebt(uint32(ss.poolId), ss.poolManager, ss.wETH),
        Math.Rounding.Down
      );
  }

  function convertToDebtAssets(uint256 shares) private view returns (uint256) {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    return
      shares.convertToAssets(
        ss.totalDebtShare,
        totalDebt(uint32(ss.poolId), ss.poolManager, ss.wETH),
        Math.Rounding.Down
      );
  }

  function getTotalNftDebtInEth(address _nft, uint256 _tokenId) private view returns (uint256) {
    DataTypes.StakeDetail storage sd = StorageSlot.getStakePoolStorage().stakeDetails[_nft][_tokenId];
    return convertToDebtAssets(sd.debtShare) + sd.unstakeFine;
  }

  function getNftDebtInEth(address _nft, uint256 _tokenId) private view returns (uint256) {
    DataTypes.StakeDetail storage sd = StorageSlot.getStakePoolStorage().stakeDetails[_nft][_tokenId];
    return convertToDebtAssets(sd.debtShare);
  }

  function convertToYieldShares(uint256 assets) private view returns (uint256) {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    return assets.convertToShares(ss.totalYieldShare, totalYield(ss.stETH), Math.Rounding.Down);
  }

  function convertToYieldAssets(uint256 shares) private view returns (uint256) {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    return shares.convertToAssets(ss.totalYieldShare, totalYield(ss.stETH), Math.Rounding.Down);
  }

  function getTotalYieldInEth(address _nft, uint256 _tokenId) private view returns (uint256) {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.StakeDetail storage sd = ss.stakeDetails[_nft][_tokenId];
    uint stEthPrice = ss.priceOracle.getPriceInEth(ss.wETH, address(ss.stETH));
    return
      stEthPrice.mulDiv(
        sd.yieldShare.convertToAssets(ss.totalYieldShare, totalYield(ss.stETH), Math.Rounding.Down),
        10 ** ss.stETH.decimals()
      );
  }

  function convertToShares(
    uint256 assets,
    uint256 totalShares,
    uint256 totalAssets,
    Math.Rounding rounding
  ) private pure returns (uint256) {
    return assets.mulDiv(totalShares + 1, totalAssets + 1, rounding);
  }

  function convertToAssets(
    uint256 shares,
    uint256 totalShares,
    uint256 totalAssets,
    Math.Rounding rounding
  ) private pure returns (uint256) {
    return shares.mulDiv(totalAssets + 1, totalShares + 1, rounding);
  }

  function calculateHealthFactor(address _nft, uint256 _tokenId) public view returns (uint256) {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();

    uint256 nftPrice = ss.priceOracle.getPriceInEth(ss.wETH, _nft);

    uint256 totalNftValue = nftPrice.percentMul(ss.nftConfigs[_nft].hfThreshold);

    uint256 totalYieldValue = getTotalYieldInEth(_nft, _tokenId);
    return (totalNftValue + totalYieldValue).wadDiv(getTotalNftDebtInEth(_nft, _tokenId));
  }

  function calculateRepayAmount(address _nft, uint256 _tokenId, uint256 _targetHf) public view returns (uint256) {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.StakeDetail storage sd = ss.stakeDetails[_nft][_tokenId];

    uint256 nftPrice = ss.priceOracle.getPriceInEth(ss.wETH, _nft);
    uint256 stEthPrice = ss.priceOracle.getPriceInEth(ss.wETH, address(ss.stETH));
    uint256 wEthPrice = ss.priceOracle.getPriceInEth(ss.wETH, address(ss.wETH));

    uint256 totalCollateralValue = nftPrice.percentMul(ss.nftConfigs[_nft].hfThreshold);
    uint256 totalYieldValue = stEthPrice.mulDiv(convertToYieldAssets(sd.yieldShare), wEthPrice);
    return getTotalNftDebtInEth(_nft, _tokenId) - (totalCollateralValue + totalYieldValue) / _targetHf;
  }

  function configNft(address _nft, uint256 _maxUnstakeFine, uint256 _unstakeHf) public {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.NftConfig storage nc = ss.nftConfigs[_nft];
    nc.maxUnstakeFine = _maxUnstakeFine;
    nc.unstakeHf = _unstakeHf;
    if (_unstakeHf < WadRayMath.WAD) {
      revert LowUnstakeHF(_unstakeHf);
    }
  }

  function activeNft(address _nft, bool acitve) public {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.NftConfig storage nc = ss.nftConfigs[_nft];
    nc.active = acitve;
  }

  function stake(address _nft, uint256 _tokenId, uint256 _borrowAmount) public {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.NftConfig memory nc = ss.nftConfigs[_nft];
    EnumerableSetUpgradeable.UintSet storage st = ss.stakedTokens[msg.sender][_nft];
    if (!nc.active) {
      revert InvalidNft(_nft);
    }

    DataTypes.StakeDetail storage sd = ss.stakeDetails[_nft][_tokenId];
    if (sd.state == DataTypes.StakeState.None) {
      IERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);
      st.add(_tokenId);
      sd.state = DataTypes.StakeState.Active;
      sd.staker = msg.sender;
      sd.nft = _nft;
      sd.tokenId = _tokenId;
    } else {
      if (msg.sender != sd.staker) {
        revert NotNftOwner(_nft, _tokenId);
      }
      if (sd.state != DataTypes.StakeState.Active) {
        revert NonStakeable(_nft, _tokenId);
      }
    }

    // calculate debt share before borrow
    uint256 debtShare = convertToDebtShares(_borrowAmount);
    uint256 borrowedAmount = ss.wETH.balanceOf(address(this));
    ss.poolManager.yieldBorrowERC20(ss.poolId, address(ss.wETH), _borrowAmount);
    borrowedAmount = ss.wETH.balanceOf(address(this)) - borrowedAmount;

    ss.wETH.withdraw(borrowedAmount);

    uint256 stETHAmount = ss.stETH.submit{value: borrowedAmount}(address(0));

    uint256 yieldShare = convertToYieldShares(stETHAmount);

    // update shares
    sd.debtShare += debtShare;
    sd.yieldShare += yieldShare;
    ss.totalDebtShare += debtShare;
    ss.totalYieldShare += yieldShare;

    uint256 hf = calculateHealthFactor(_nft, _tokenId);
    if (hf <= nc.unstakeHf) {
      revert LowHealthFactor(_nft, _tokenId, hf);
    }
  }

  function repay(address _nft, uint256 _tokenId, uint256 _repayDebt) public {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.StakeDetail storage sd = ss.stakeDetails[_nft][_tokenId];
    EnumerableSetUpgradeable.UintSet storage st = ss.stakedTokens[msg.sender][_nft];

    if (sd.staker == address(0) || !st.contains(_tokenId)) {
      revert NonRepayable(_nft, _tokenId);
    }

    // 1. withdraw eth from lido and repay if possible
    uint256 repaidFromLido = 0;
    if (sd.repayRequestId != 0 && sd.state == DataTypes.StakeState.Unstaking) {
      uint256[] memory requestIds = new uint256[](1);
      requestIds[0] = sd.repayRequestId;
      IUnsetETH.WithdrawalRequestStatus memory withdrawStatus = ss.unsetETH.getWithdrawalStatus(requestIds)[0];

      if (withdrawStatus.isFinalized && !withdrawStatus.isClaimed) {
        uint256 claimedEth = address(this).balance;
        ss.unsetETH.claimWithdrawal(sd.repayRequestId);
        claimedEth = address(this).balance - claimedEth;
        ss.wETH.deposit{value: claimedEth}();
        repaidFromLido = claimedEth;
        sd.state = DataTypes.StakeState.Active;
      }
    }

    uint256 nftDebt = getNftDebtInEth(_nft, _tokenId);
    uint256 unstakeFine = sd.unstakeFine;
    uint256 repayDebt = 0;
    uint256 repayFine = 0;

    // compute repay value
    uint256 transferValue = _repayDebt;
    if (repaidFromLido > (nftDebt + unstakeFine)) {
      transferValue = 0;
      repayDebt = nftDebt;
      repayFine = unstakeFine;
    } else {
      uint256 maxRepayFromSender = nftDebt + unstakeFine - repaidFromLido;
      if (transferValue > maxRepayFromSender) {
        transferValue = maxRepayFromSender;
      }
      uint256 repayValue = repaidFromLido + transferValue;
      if (repayValue > nftDebt) {
        repayDebt = nftDebt;
        repayFine = repayValue - nftDebt;
      } else {
        repayDebt = repayValue;
        repayFine = 0;
      }
    }

    // transfer eth from sender
    if (transferValue > 0) {
      ss.wETH.safeTransferFrom(msg.sender, address(this), transferValue);
    }

    // 2 repay lending pool
    if (repayDebt > 0) {
      ss.poolManager.yieldRepayERC20(ss.poolId, address(ss.wETH), repayDebt);
      uint256 repayDebtShare = convertToDebtShares(repayDebt);

      // update shares
      sd.debtShare -= repayDebtShare;
      ss.totalDebtShare -= repayDebtShare;
    }

    // 3. repay fine
    if (repayFine > 0) {
      sd.unstakeFine -= repayFine;
    }
  }

  function unstake(address _nft, uint256 _tokenId, uint256 _unstakeFine) public {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.StakeDetail storage sd = ss.stakeDetails[_nft][_tokenId];
    DataTypes.NftConfig memory nc = ss.nftConfigs[_nft];
    EnumerableSetUpgradeable.UintSet storage st = ss.stakedTokens[msg.sender][_nft];
    if (sd.staker == address(0) || !st.contains(_tokenId)) {
      revert NonUnstakeable(_nft, _tokenId);
    }
    if (sd.state != DataTypes.StakeState.Active) {
      revert NonUnstakeable(_nft, _tokenId);
    }

    // sender must be bot or nft owner
    if (msg.sender == ss.bot) {
      if (_unstakeFine > nc.maxUnstakeFine) {
        revert InvalidFine(_unstakeFine);
      }
      uint256 hf = calculateHealthFactor(_nft, _tokenId);

      if (hf > nc.unstakeHf) {
        revert NonUnstakeable(_nft, _tokenId);
      }
      sd.unstakeFine = _unstakeFine;
      ss.fines += sd.unstakeFine;
    } else if (msg.sender != sd.staker) {
      revert NotNftOwner(_nft, _tokenId);
    }

    uint256[] memory requestAmount = new uint256[](1);
    requestAmount[0] = convertToYieldAssets(sd.yieldShare);
    // update requestId
    sd.repayRequestId = ss.unsetETH.requestWithdrawals(requestAmount, address(this))[0];
    // update state
    sd.state = DataTypes.StakeState.Unstaking;

    // update shares
    ss.totalYieldShare -= sd.yieldShare;
    sd.yieldShare = 0;
  }

  function withdrawNFT(address _nft, uint256 _tokenId) public {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.StakeDetail storage sd = ss.stakeDetails[_nft][_tokenId];
    EnumerableSetUpgradeable.UintSet storage st = ss.stakedTokens[msg.sender][_nft];

    if (sd.staker != msg.sender) {
      revert NotNftOwner(_nft, _tokenId);
    }

    // debt must be zero
    uint256 totalDebtValue = getTotalNftDebtInEth(_nft, _tokenId);
    if (totalDebtValue > 0) {
      revert DebtUnpaid(_nft, _tokenId);
    }

    // transfer nft
    IERC721(_nft).safeTransferFrom(address(this), sd.staker, _tokenId);

    // withdraw all yield
    if (sd.yieldShare > 0) {
      withdrawYield(_nft, _tokenId, convertToYieldAssets(sd.yieldShare));
    }
    // delete stake detail
    delete ss.stakeDetails[_nft][_tokenId];

    // remove staked token
    st.remove(_tokenId);
  }

  function withdrawYield(address _nft, uint256 _tokenId, uint256 _requestAmount) public {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    DataTypes.StakeDetail storage sd = ss.stakeDetails[_nft][_tokenId];
    DataTypes.NftConfig memory nc = ss.nftConfigs[_nft];

    if (msg.sender != sd.staker) {
      revert NotNftOwner(_nft, _tokenId);
    }
    uint256 totalDebtValue = getTotalNftDebtInEth(_nft, _tokenId);
    uint256 totalYieldValue = getTotalYieldInEth(_nft, _tokenId);
    if (totalYieldValue < totalDebtValue) {
      revert NonWithdrawable(_nft, _tokenId);
    }
    if (_requestAmount > (totalYieldValue - totalDebtValue)) {
      revert NonWithdrawable(_nft, _tokenId);
    }

    uint256[] memory requests = new uint256[](1);
    requests[0] = _requestAmount;

    uint256 requestId = ss.unsetETH.requestWithdrawals(requests, address(this))[0];

    // update storage
    uint withdrawnShare = convertToDebtShares(_requestAmount);
    ss.withdrawRequestIds[msg.sender].add(requestId);
    sd.yieldShare -= withdrawnShare;
    ss.totalYieldShare -= withdrawnShare;

    // check hf
    uint256 hf = calculateHealthFactor(_nft, _tokenId);

    if (hf <= nc.unstakeHf) {
      revert LowHealthFactor(_nft, _tokenId, hf);
    }
  }

  function claimYield(uint256 _requestId) external {
    DataTypes.StakePoolStorage storage ss = StorageSlot.getStakePoolStorage();
    if (!ss.withdrawRequestIds[msg.sender].contains(_requestId)) {
      revert NonClaimable(_requestId);
    }
    uint256[] memory requestIds = new uint256[](1);
    requestIds[0] = _requestId;
    IUnsetETH.WithdrawalRequestStatus memory withdrawStatus = ss.unsetETH.getWithdrawalStatus(requestIds)[0];

    if (withdrawStatus.isFinalized && !withdrawStatus.isClaimed) {
      uint256 claimedEth = address(this).balance;
      ss.unsetETH.claimWithdrawal(_requestId);
      claimedEth = address(this).balance - claimedEth;
      Address.sendValue(payable(msg.sender), claimedEth);
      ss.withdrawRequestIds[msg.sender].remove(_requestId);
    }
  }
}
