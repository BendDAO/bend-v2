// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

import {IAddressProvider} from './interfaces/IAddressProvider.sol';
import {IACLManager} from './interfaces/IACLManager.sol';
import {IPoolManager} from './interfaces/IPoolManager.sol';
import {IPriceOracleGetter} from './interfaces/IPriceOracleGetter.sol';
import {IWETH} from './interfaces/IWETH.sol';
import {IStETH} from './interfaces/IStETH.sol';
import {IUnstETH} from './interfaces/IUnstETH.sol';

import {Constants} from './libraries/helpers/Constants.sol';
import {Errors} from './libraries/helpers/Errors.sol';

import {PercentageMath} from './libraries/math/PercentageMath.sol';
import {WadRayMath} from './libraries/math/WadRayMath.sol';
import {MathUtils} from './libraries/math/MathUtils.sol';
import {ShareUtils} from './libraries/math/ShareUtils.sol';

contract YieldEthStaking is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using PercentageMath for uint256;
  using ShareUtils for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;
  using Math for uint256;

  event SetNftActive(address indexed nft, bool isActive);
  event SetNftStakeParams(address indexed nft, uint16 leverageFactor, uint16 liquidationThreshold);
  event SetNftUnstakeParams(address indexed nft, uint16 maxUnstakeFine, uint256 unstakeHeathFactor);
  event Stake(address indexed nft, uint256 indexed tokenId, uint256 amount);
  event Unstake(address indexed nft, uint256 indexed tokenId, uint256 amount);
  event Repay(address indexed nft, uint256 indexed tokenId, uint256 amount);

  struct YieldNftConfig {
    bool isActive;
    uint16 leverageFactor; // e.g. 50000 -> 500%
    uint16 liquidationThreshold; // e.g. 9000 -> 90%
    uint16 maxUnstakeFine; // e.g. 1ether -> 1e18
    uint256 unstakeHeathFactor; // 18 decimals, e.g. 1.0 -> 1e18
  }

  struct YieldStakeData {
    uint32 poolId;
    uint8 state;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 unstakeFine;
    uint256 stEthWithdrawAmount;
    uint256 stEthWithdrawReqId;
  }

  IAddressProvider public addressProvider;
  IPoolManager public poolManager;
  IWETH public weth;
  IStETH public stETH;
  IUnstETH public unstETH;
  uint256 public totalDebtShare;
  uint256 public totalYieldShare;
  uint256 public totalUnstakeFine;
  address public botAdmin;

  mapping(address => YieldNftConfig) nftConfigs;
  mapping(address => mapping(uint256 => YieldStakeData)) stakeDatas;

  modifier onlyPoolAdmin() {
    __onlyPoolAdmin();
    _;
  }

  function __onlyPoolAdmin() internal view {
    require(IACLManager(addressProvider.getACLManager()).isPoolAdmin(msg.sender), Errors.CALLER_NOT_POOL_ADMIN);
  }

  constructor() {
    _disableInitializers();
  }

  function initialize(address addressProvider_, address weth_, address stETH_, address unstETH_) public initializer {
    __Pausable_init();
    __ReentrancyGuard_init();

    addressProvider = IAddressProvider(addressProvider_);
    weth = IWETH(weth_);
    stETH = IStETH(stETH_);
    unstETH = IUnstETH(unstETH_);

    poolManager = IPoolManager(addressProvider.getPoolManager());
    weth.approve(address(poolManager), type(uint256).max);
    stETH.approve(address(unstETH), type(uint256).max);
  }

  /****************************************************************************/
  /* Configure Methods */
  /****************************************************************************/

  function setNftActive(address nft, bool active) public onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.isActive = active;

    emit SetNftActive(nft, active);
  }

  function setNftStakeParams(address nft, uint16 leverageFactor, uint16 liquidationThreshold) public onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.leverageFactor = leverageFactor;
    nc.liquidationThreshold = liquidationThreshold;

    emit SetNftStakeParams(nft, leverageFactor, liquidationThreshold);
  }

  function setNftUnstakeParams(address nft, uint16 maxUnstakeFine, uint256 unstakeHeathFactor) public onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.maxUnstakeFine = maxUnstakeFine;
    nc.unstakeHeathFactor = unstakeHeathFactor;

    emit SetNftUnstakeParams(nft, maxUnstakeFine, unstakeHeathFactor);
  }

  function setPause(bool paused) public onlyPoolAdmin {
    if (paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  /****************************************************************************/
  /* Service Methods */
  /****************************************************************************/

  struct StakeLocalVars {
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256 totalDebtAmount;
    uint256 nftPriceInEth;
    uint256 maxBorrowAmount;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 stETHAmount;
    uint256 totalYieldBeforeSubmit;
  }

  function stake(uint32 poolId, address nft, uint256 tokenId, uint256 borrowAmount) public whenNotPaused nonReentrant {
    StakeLocalVars memory vars;

    YieldNftConfig storage nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolManager.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);

    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    if (sd.state == 0) {
      require(vars.nftLockerAddr == address(0), Errors.YIELD_ETH_LOCKER_EXIST);

      vars.totalDebtAmount = borrowAmount;
    } else {
      require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_LOCKER_NOT_SAME);
      require(sd.state == Constants.YIELD_STATUS_ACTIVE, Errors.YIELD_ETH_STATUS_NOT_ACTIVE);
      require(sd.poolId == poolId, Errors.YIELD_ETH_POOL_NOT_SAME);

      vars.totalDebtAmount = convertToDebtAssets(poolId, sd.debtShare) + borrowAmount;
    }

    vars.nftPriceInEth = getNftPriceInEth(nft);
    vars.maxBorrowAmount = vars.nftPriceInEth.percentMul(nc.leverageFactor);
    require(vars.totalDebtAmount <= vars.maxBorrowAmount, Errors.YIELD_ETH_EXCEED_MAX_BORROWABLE);

    // calculate debt share before borrow
    vars.debtShare = convertToDebtShares(poolId, borrowAmount);

    // borrow from lending pool
    poolManager.yieldBorrowERC20(poolId, address(weth), borrowAmount);

    // stake in lido and got the stETH
    vars.totalYieldBeforeSubmit = getTotalYield();
    weth.withdraw(borrowAmount);
    vars.stETHAmount = stETH.submit{value: borrowAmount}(address(0));
    vars.yieldShare = _convertToYieldSharesBeforeSubmit(vars.stETHAmount, vars.totalYieldBeforeSubmit);

    // update nft shares
    if (sd.state == 0) {
      sd.poolId = poolId;
      sd.state = Constants.YIELD_STATUS_ACTIVE;
    }
    sd.debtShare += vars.debtShare;
    sd.yieldShare += vars.yieldShare;

    // update global shares
    totalDebtShare += vars.debtShare;
    totalYieldShare += vars.yieldShare;

    poolManager.yieldSetERC721TokenData(poolId, nft, tokenId, true, address(weth));

    // check hf
    uint256 hf = calculateHealthFactor(nft, nc, sd);
    require(hf >= nc.unstakeHeathFactor, Errors.YIELD_ETH_HEATH_FACTOR_TOO_LOW);
  }

  struct UnstakeLocalVars {
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256[] requestAmounts;
  }

  function unstake(uint32 poolId, address nft, uint256 tokenId, uint256 unstakeFine) public whenNotPaused nonReentrant {
    UnstakeLocalVars memory vars;

    YieldNftConfig storage nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolManager.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_LOCKER_NOT_SAME);

    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    require(sd.state == Constants.YIELD_STATUS_ACTIVE, Errors.YIELD_ETH_STATUS_NOT_ACTIVE);
    require(sd.poolId == poolId, Errors.YIELD_ETH_POOL_NOT_SAME);

    // sender must be bot or nft owner
    if (msg.sender == botAdmin) {
      require(unstakeFine <= nc.maxUnstakeFine, Errors.YIELD_ETH_EXCEED_MAX_FINE);

      uint256 hf = calculateHealthFactor(nft, nc, sd);
      require(hf < nc.unstakeHeathFactor, Errors.YIELD_ETH_HEATH_FACTOR_TOO_HIGH);

      sd.unstakeFine = unstakeFine;
      totalUnstakeFine += unstakeFine;
    }

    sd.state = Constants.YIELD_STATUS_UNSTAKE;
    sd.stEthWithdrawAmount = convertToYieldAssets(sd.yieldShare);

    vars.requestAmounts = new uint256[](1);
    vars.requestAmounts[0] = sd.stEthWithdrawAmount;
    sd.stEthWithdrawReqId = unstETH.requestWithdrawals(vars.requestAmounts, address(this))[0];

    // update shares
    totalYieldShare -= sd.yieldShare;
    sd.yieldShare = 0;
  }

  struct RepayLocalVars {
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256[] requestIds;
    IUnstETH.WithdrawalRequestStatus withdrawStatus;
    uint256 claimedEth;
    uint256 nftDebt;
    uint256 nftDebtWithFine;
    uint256 remainAmount;
    uint256 extraAmount;
  }

  function repay(uint32 poolId, address nft, uint256 tokenId) public whenNotPaused nonReentrant {
    RepayLocalVars memory vars;

    YieldNftConfig memory nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    require(sd.state == Constants.YIELD_STATUS_UNSTAKE, Errors.YIELD_ETH_STATUS_NOT_UNSTAKE);
    require(sd.poolId == poolId, Errors.YIELD_ETH_POOL_NOT_SAME);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolManager.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_LOCKER_NOT_SAME);

    // withdraw eth from lido and repay if possible
    vars.requestIds = new uint256[](1);
    vars.requestIds[0] = sd.stEthWithdrawReqId;
    vars.withdrawStatus = unstETH.getWithdrawalStatus(vars.requestIds)[0];
    require(
      vars.withdrawStatus.isFinalized && !vars.withdrawStatus.isClaimed,
      Errors.YIELD_ETH_STETH_WITHDRAW_NOT_READY
    );

    vars.claimedEth = address(this).balance;
    unstETH.claimWithdrawal(sd.stEthWithdrawReqId);
    vars.claimedEth = address(this).balance - vars.claimedEth;

    weth.deposit{value: vars.claimedEth}();

    vars.nftDebt = _getNftDebtInEth(sd);
    vars.nftDebtWithFine = vars.nftDebt + sd.unstakeFine;

    // compute repay value
    if (vars.claimedEth >= vars.nftDebtWithFine) {
      vars.remainAmount = vars.claimedEth - vars.nftDebtWithFine;
    } else {
      vars.extraAmount = vars.nftDebtWithFine - vars.claimedEth;
    }

    // transfer eth from sender
    if (vars.extraAmount > 0) {
      weth.transferFrom(msg.sender, address(this), vars.extraAmount);
    }

    if (vars.remainAmount > 0) {
      weth.transferFrom(address(this), msg.sender, vars.remainAmount);
    }

    // repay lending pool
    poolManager.yieldRepayERC20(poolId, address(weth), vars.nftDebt);

    poolManager.yieldSetERC721TokenData(poolId, nft, tokenId, false, address(weth));

    // update shares
    totalDebtShare -= sd.debtShare;

    delete stakeDatas[nft][tokenId];
  }

  /****************************************************************************/
  /* Query Methods */
  /****************************************************************************/

  function getTotalDebt(uint32 poolId) public view returns (uint256) {
    return poolManager.getYieldERC20BorrowBalance(poolId, address(weth), address(this));
  }

  function getTotalYield() public view returns (uint256) {
    return stETH.balanceOf(address(this));
  }

  function getNftValueInETH(address nft) public view returns (uint256) {
    YieldNftConfig storage nc = nftConfigs[nft];

    uint256 nftPrice = getNftPriceInEth(nft);
    uint256 totalNftValue = nftPrice.percentMul(nc.liquidationThreshold);
    return totalNftValue;
  }

  function getNftDebtInEth(address nft, uint256 tokenId) public view returns (uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return _getNftDebtInEth(sd);
  }

  function getNftYieldInEth(address nft, uint256 tokenId) public view returns (uint256, uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return _getNftYieldInEth(sd);
  }

  function getNftStakeData(address nft, uint256 tokenId) public view returns (uint32, uint8, uint256, uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return (sd.poolId, sd.state, sd.debtShare, sd.yieldShare);
  }

  function getNftUnstakeData(address nft, uint256 tokenId) public view returns (uint256, uint256, uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return (sd.unstakeFine, sd.stEthWithdrawAmount, sd.stEthWithdrawReqId);
  }

  /****************************************************************************/
  /* Internal Methods */
  /****************************************************************************/

  function convertToDebtShares(uint32 poolId, uint256 assets) public view returns (uint256) {
    return assets.convertToShares(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function convertToDebtAssets(uint32 poolId, uint256 shares) public view returns (uint256) {
    return shares.convertToAssets(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function convertToYieldShares(uint256 assets) public view returns (uint256) {
    return assets.convertToShares(totalYieldShare, getTotalYield(), Math.Rounding.Down);
  }

  function convertToYieldAssets(uint256 shares) public view returns (uint256) {
    return shares.convertToAssets(totalYieldShare, getTotalYield(), Math.Rounding.Down);
  }

  function _convertToYieldSharesBeforeSubmit(uint256 assets, uint256 totalYield) internal view returns (uint256) {
    return assets.convertToShares(totalYieldShare, totalYield, Math.Rounding.Down);
  }

  function _getNftDebtInEth(YieldStakeData storage sd) internal view returns (uint256) {
    return convertToDebtAssets(sd.poolId, sd.debtShare);
  }

  function _getNftYieldInEth(YieldStakeData storage sd) internal view returns (uint256, uint256) {
    uint256 stEthAmount = convertToYieldAssets(sd.yieldShare);
    uint256 stEthPrice = getStETHPriceInEth();
    return (stEthAmount, stEthAmount.mulDiv(stEthPrice, 10 ** stETH.decimals()));
  }

  function getStETHPriceInEth() internal view returns (uint256) {
    IPriceOracleGetter priceOracle = IPriceOracleGetter(addressProvider.getPriceOracle());
    uint256 stETHPriceInBase = priceOracle.getAssetPrice(address(stETH));
    uint256 ethPriceInBase = priceOracle.getAssetPrice(address(weth));
    return stETHPriceInBase.mulDiv(10 ** weth.decimals(), ethPriceInBase);
  }

  function getNftPriceInEth(address nft) internal view returns (uint256) {
    IPriceOracleGetter priceOracle = IPriceOracleGetter(addressProvider.getPriceOracle());
    uint256 nftPriceInBase = priceOracle.getAssetPrice(nft);
    uint256 ethPriceInBase = priceOracle.getAssetPrice(address(weth));
    return nftPriceInBase.mulDiv(10 ** weth.decimals(), ethPriceInBase);
  }

  function calculateHealthFactor(
    address nft,
    YieldNftConfig storage nc,
    YieldStakeData storage sd
  ) internal view returns (uint256) {
    uint256 nftPrice = getNftPriceInEth(nft);
    uint256 totalNftValue = nftPrice.percentMul(nc.liquidationThreshold);

    (, uint256 totalYieldValue) = _getNftYieldInEth(sd);
    uint256 totalDebtValue = _getNftDebtInEth(sd);

    return (totalNftValue + totalYieldValue).wadDiv(totalDebtValue);
  }

  /**
   * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
   */
  receive() external payable {
    require(msg.sender == address(weth) || msg.sender == address(unstETH), 'Receive not allowed');
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert('Fallback not allowed');
  }
}
