// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {PausableUpgradeable} from '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';
import {IACLManager} from 'src/interfaces/IACLManager.sol';
import {IPoolManager} from 'src/interfaces/IPoolManager.sol';
import {IYield} from 'src/interfaces/IYield.sol';
import {IPriceOracleGetter} from 'src/interfaces/IPriceOracleGetter.sol';
import {IYieldAccount} from 'src/interfaces/IYieldAccount.sol';
import {IYieldRegistry} from 'src/interfaces/IYieldRegistry.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';
import {Errors} from 'src/libraries/helpers/Errors.sol';

import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {ShareUtils} from 'src/libraries/math/ShareUtils.sol';

abstract contract YieldEthStakingBase is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20Metadata;
  using PercentageMath for uint256;
  using ShareUtils for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;
  using Math for uint256;

  event SetNftActive(address indexed nft, bool isActive);
  event SetNftStakeParams(address indexed nft, uint16 leverageFactor, uint16 liquidationThreshold);
  event SetNftUnstakeParams(address indexed nft, uint16 maxUnstakeFine, uint256 unstakeHeathFactor);
  event SetBotAdmin(address oldAdmin, address newAdmin);

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
    address yieldAccount;
    uint32 poolId;
    uint8 state;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 unstakeFine;
    uint256 withdrawAmount;
    uint256 withdrawReqId;
  }

  IAddressProvider public addressProvider;
  IPoolManager public poolManager;
  IYield public poolYield;
  IYieldRegistry public yieldRegistry;
  IERC20Metadata public underlyingAsset;
  address public botAdmin;
  uint256 public totalDebtShare;
  uint256 public totalUnstakeFine;
  mapping(address => address) public yieldAccounts;
  mapping(address => uint256) public accountYieldShares;
  mapping(address => YieldNftConfig) nftConfigs;
  mapping(address => mapping(uint256 => YieldStakeData)) stakeDatas;

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[20] private __gap;

  modifier onlyPoolAdmin() {
    __onlyPoolAdmin();
    _;
  }

  function __onlyPoolAdmin() internal view {
    require(IACLManager(addressProvider.getACLManager()).isPoolAdmin(msg.sender), Errors.CALLER_NOT_POOL_ADMIN);
  }

  function __YieldStakingBase_init(address addressProvider_, address underlyingAsset_) internal onlyInitializing {
    __Pausable_init();
    __ReentrancyGuard_init();

    addressProvider = IAddressProvider(addressProvider_);

    poolManager = IPoolManager(addressProvider.getPoolManager());
    poolYield = IYield(addressProvider.getPoolModuleProxy(Constants.MODULEID__YIELD));
    yieldRegistry = IYieldRegistry(addressProvider.getYieldRegistry());

    underlyingAsset = IERC20Metadata(underlyingAsset_);

    underlyingAsset.approve(address(poolManager), type(uint256).max);
  }

  /****************************************************************************/
  /* Configure Methods */
  /****************************************************************************/

  function setNftActive(address nft, bool active) public virtual onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.isActive = active;

    emit SetNftActive(nft, active);
  }

  function setNftStakeParams(
    address nft,
    uint16 leverageFactor,
    uint16 liquidationThreshold
  ) public virtual onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.leverageFactor = leverageFactor;
    nc.liquidationThreshold = liquidationThreshold;

    emit SetNftStakeParams(nft, leverageFactor, liquidationThreshold);
  }

  function setNftUnstakeParams(
    address nft,
    uint16 maxUnstakeFine,
    uint256 unstakeHeathFactor
  ) public virtual onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.maxUnstakeFine = maxUnstakeFine;
    nc.unstakeHeathFactor = unstakeHeathFactor;

    emit SetNftUnstakeParams(nft, maxUnstakeFine, unstakeHeathFactor);
  }

  function setBotAdmin(address newAdmin) public virtual onlyPoolAdmin {
    address oldAdmin = botAdmin;
    botAdmin = newAdmin;

    emit SetBotAdmin(oldAdmin, newAdmin);
  }

  function setPause(bool paused) public virtual onlyPoolAdmin {
    if (paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  /****************************************************************************/
  /* Service Methods */
  /****************************************************************************/

  function createYieldAccount(address user) public virtual returns (address) {
    if (user == address(0)) {
      user = msg.sender;
    }
    address account = yieldRegistry.createYieldAccount(address(this));
    yieldAccounts[user] = account;
    return account;
  }

  struct StakeLocalVars {
    IYieldAccount yieldAccout;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256 totalDebtAmount;
    uint256 nftPriceInUnderlyingAsset;
    uint256 maxBorrowAmount;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 yieldAmount;
    uint256 totalYieldBeforeSubmit;
  }

  function stake(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 borrowAmount
  ) public virtual whenNotPaused nonReentrant {
    StakeLocalVars memory vars;

    vars.yieldAccout = IYieldAccount(yieldAccounts[msg.sender]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    YieldNftConfig storage nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
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

    vars.nftPriceInUnderlyingAsset = getNftPriceInUnderlyingAsset(nft);
    vars.maxBorrowAmount = vars.nftPriceInUnderlyingAsset.percentMul(nc.leverageFactor);
    require(vars.totalDebtAmount <= vars.maxBorrowAmount, Errors.YIELD_ETH_EXCEED_MAX_BORROWABLE);

    // calculate debt share before borrow
    vars.debtShare = convertToDebtShares(poolId, borrowAmount);

    // borrow from lending pool
    poolYield.yieldBorrowERC20(poolId, address(underlyingAsset), borrowAmount);

    // stake in protocol and got the yield
    vars.totalYieldBeforeSubmit = getAccountTotalYield(address(vars.yieldAccout));
    vars.yieldAmount = protocolDeposit(sd, borrowAmount);
    vars.yieldShare = _convertToYieldSharesBeforeSubmit(
      address(vars.yieldAccout),
      vars.yieldAmount,
      vars.totalYieldBeforeSubmit
    );

    // update nft shares
    if (sd.state == 0) {
      sd.yieldAccount = address(vars.yieldAccout);
      sd.poolId = poolId;
      sd.state = Constants.YIELD_STATUS_ACTIVE;
    }
    sd.debtShare += vars.debtShare;
    sd.yieldShare += vars.yieldShare;

    // update global shares
    totalDebtShare += vars.debtShare;
    accountYieldShares[address(vars.yieldAccout)] += vars.yieldShare;

    poolYield.yieldSetERC721TokenData(poolId, nft, tokenId, true, address(underlyingAsset));

    // check hf
    uint256 hf = calculateHealthFactor(nft, nc, sd);
    require(hf >= nc.unstakeHeathFactor, Errors.YIELD_ETH_HEATH_FACTOR_TOO_LOW);
  }

  struct UnstakeLocalVars {
    IYieldAccount yieldAccout;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256[] requestAmounts;
  }

  function unstake(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 unstakeFine
  ) public virtual whenNotPaused nonReentrant {
    UnstakeLocalVars memory vars;

    vars.yieldAccout = IYieldAccount(yieldAccounts[msg.sender]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    YieldNftConfig storage nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
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
    sd.withdrawAmount = convertToYieldAssets(address(vars.yieldAccout), sd.yieldShare);

    protocolRequestWithdrawal(sd);

    // update shares
    accountYieldShares[address(vars.yieldAccout)] -= sd.yieldShare;
    sd.yieldShare = 0;
  }

  struct RepayLocalVars {
    IYieldAccount yieldAccout;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256 claimedYield;
    uint256 nftDebt;
    uint256 nftDebtWithFine;
    uint256 remainAmount;
    uint256 extraAmount;
    bool isOK;
  }

  function repay(uint32 poolId, address nft, uint256 tokenId) public virtual whenNotPaused nonReentrant {
    RepayLocalVars memory vars;

    vars.yieldAccout = IYieldAccount(yieldAccounts[msg.sender]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    YieldNftConfig memory nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    require(sd.state == Constants.YIELD_STATUS_UNSTAKE, Errors.YIELD_ETH_STATUS_NOT_UNSTAKE);
    require(sd.poolId == poolId, Errors.YIELD_ETH_POOL_NOT_SAME);

    require(protocolIsClaimReady(sd), Errors.YIELD_ETH_WITHDRAW_NOT_READY);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_LOCKER_NOT_SAME);

    // withdraw yield from protocol and repay if possible

    vars.claimedYield = protocolClaimWithdraw(sd);

    vars.nftDebt = _getNftDebtInUnderlyingAsset(sd);
    vars.nftDebtWithFine = vars.nftDebt + sd.unstakeFine;

    // compute repay value
    if (vars.claimedYield >= vars.nftDebtWithFine) {
      vars.remainAmount = vars.claimedYield - vars.nftDebtWithFine;
    } else {
      vars.extraAmount = vars.nftDebtWithFine - vars.claimedYield;
    }

    // transfer eth from sender
    if (vars.extraAmount > 0) {
      underlyingAsset.safeTransferFrom(vars.nftOwner, address(this), vars.extraAmount);
    }

    if (vars.remainAmount > 0) {
      underlyingAsset.safeTransfer(vars.nftOwner, vars.remainAmount);
    }

    // repay lending pool
    poolYield.yieldRepayERC20(poolId, address(underlyingAsset), vars.nftDebt);

    poolYield.yieldSetERC721TokenData(poolId, nft, tokenId, false, address(underlyingAsset));

    // update shares
    totalDebtShare -= sd.debtShare;

    delete stakeDatas[nft][tokenId];
  }

  /****************************************************************************/
  /* Query Methods */
  /****************************************************************************/

  function getTotalDebt(uint32 poolId) public view virtual returns (uint256) {
    return poolYield.getYieldERC20BorrowBalance(poolId, address(underlyingAsset), address(this));
  }

  function getAccountTotalYield(address /*account*/) public view virtual returns (uint256) {
    return 0;
  }

  function getNftValueInUnderlyingAsset(address nft) public view virtual returns (uint256) {
    YieldNftConfig storage nc = nftConfigs[nft];

    uint256 nftPrice = getNftPriceInUnderlyingAsset(nft);
    uint256 totalNftValue = nftPrice.percentMul(nc.liquidationThreshold);
    return totalNftValue;
  }

  function getNftDebtInUnderlyingAsset(address nft, uint256 tokenId) public view virtual returns (uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return _getNftDebtInUnderlyingAsset(sd);
  }

  function getNftYieldInUnderlyingAsset(address nft, uint256 tokenId) public view virtual returns (uint256, uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return _getNftYieldInUnderlyingAsset(sd);
  }

  function getNftStakeData(address nft, uint256 tokenId) public view virtual returns (uint32, uint8, uint256, uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];

    uint8 state = sd.state;
    if (sd.state == Constants.YIELD_STATUS_UNSTAKE) {
      if (protocolIsClaimReady(sd)) {
        state = Constants.YIELD_STATUS_CLAIM;
      }
    }

    uint256 debtAmount = _getNftDebtInUnderlyingAsset(sd);
    (uint256 yieldAmount, ) = _getNftYieldInUnderlyingAsset(sd);

    return (sd.poolId, state, debtAmount, yieldAmount);
  }

  function getNftUnstakeData(address nft, uint256 tokenId) public view virtual returns (uint256, uint256, uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return (sd.unstakeFine, sd.withdrawAmount, sd.withdrawReqId);
  }

  /****************************************************************************/
  /* Internal Methods */
  /****************************************************************************/
  function protocolDeposit(YieldStakeData storage sd, uint256 amount) internal virtual returns (uint256) {}

  function protocolRequestWithdrawal(YieldStakeData storage sd) internal virtual {}

  function protocolClaimWithdraw(YieldStakeData storage sd) internal virtual returns (uint256) {}

  function protocolIsClaimReady(YieldStakeData storage sd) internal view virtual returns (bool) {}

  function convertToDebtShares(uint32 poolId, uint256 assets) public view virtual returns (uint256) {
    return assets.convertToShares(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function convertToDebtAssets(uint32 poolId, uint256 shares) public view virtual returns (uint256) {
    return shares.convertToAssets(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function convertToYieldShares(address account, uint256 assets) public view virtual returns (uint256) {
    return assets.convertToShares(accountYieldShares[account], getAccountTotalYield(account), Math.Rounding.Down);
  }

  function convertToYieldAssets(address account, uint256 shares) public view virtual returns (uint256) {
    return shares.convertToAssets(accountYieldShares[account], getAccountTotalYield(account), Math.Rounding.Down);
  }

  function _convertToYieldSharesBeforeSubmit(
    address account,
    uint256 assets,
    uint256 totalYield
  ) internal view virtual returns (uint256) {
    return assets.convertToShares(accountYieldShares[account], totalYield, Math.Rounding.Down);
  }

  function _getNftDebtInUnderlyingAsset(YieldStakeData storage sd) internal view virtual returns (uint256) {
    return convertToDebtAssets(sd.poolId, sd.debtShare);
  }

  function _getNftYieldInUnderlyingAsset(YieldStakeData storage sd) internal view virtual returns (uint256, uint256) {
    // here's yieldAmount are just the raw amount (shares) for the token in the protocol, not the actual underlying assets
    uint256 yieldAmount = convertToYieldAssets(sd.yieldAccount, sd.yieldShare);
    uint256 underAmount = getProtocolTokenAmountInUnderlyingAsset(yieldAmount);

    // yieldValue are calculated by the raw amount & protocol token price
    uint256 yieldPrice = getProtocolTokenPriceInUnderlyingAsset();
    return (underAmount, yieldAmount.mulDiv(yieldPrice, 10 ** getProtocolTokenDecimals()));
  }

  function getProtocolTokenDecimals() internal view virtual returns (uint8) {
    return 0;
  }

  function getProtocolTokenPriceInUnderlyingAsset() internal view virtual returns (uint256) {
    return 0;
  }

  function getProtocolTokenAmountInUnderlyingAsset(uint256 yieldAmount) internal view virtual returns (uint256) {
    // stETH, eETH is rebase model & 1:1 to the underlying
    // but sDAI is not rebase model, the share are fixed
    return yieldAmount;
  }

  function getNftPriceInUnderlyingAsset(address nft) internal view virtual returns (uint256) {
    IPriceOracleGetter priceOracle = IPriceOracleGetter(addressProvider.getPriceOracle());
    uint256 nftPriceInBase = priceOracle.getAssetPrice(nft);
    uint256 underlyingAssetPriceInBase = priceOracle.getAssetPrice(address(underlyingAsset));
    return nftPriceInBase.mulDiv(10 ** underlyingAsset.decimals(), underlyingAssetPriceInBase);
  }

  function calculateHealthFactor(
    address nft,
    YieldNftConfig storage nc,
    YieldStakeData storage sd
  ) internal view virtual returns (uint256) {
    uint256 nftPrice = getNftPriceInUnderlyingAsset(nft);
    uint256 totalNftValue = nftPrice.percentMul(nc.liquidationThreshold);

    (, uint256 totalYieldValue) = _getNftYieldInUnderlyingAsset(sd);
    uint256 totalDebtValue = _getNftDebtInUnderlyingAsset(sd);

    return (totalNftValue + totalYieldValue).wadDiv(totalDebtValue);
  }
}
