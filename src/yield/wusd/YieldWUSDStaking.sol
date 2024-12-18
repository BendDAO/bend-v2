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

import {IWUSDStaking} from './IWUSDStaking.sol';

contract YieldWUSDStaking is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20Metadata;
  using PercentageMath for uint256;
  using ShareUtils for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;
  using Math for uint256;

  event SetNftActive(address indexed nft, bool isActive);
  event SetNftStakeParams(address indexed nft, uint16 leverageFactor, uint16 collateralFactor);
  event SetNftUnstakeParams(address indexed nft, uint256 maxUnstakeFine, uint256 unstakeHeathFactor);
  event SetBotAdmin(address oldAdmin, address newAdmin);

  event Stake(address indexed user, address indexed nft, uint256 indexed tokenId, uint256 amount);
  event Unstake(address indexed user, address indexed nft, uint256 indexed tokenId, uint256 amount);
  event Repay(address indexed user, address indexed nft, uint256 indexed tokenId, uint256 amount);
  event RepayPart(address indexed user, address indexed nft, uint256 indexed tokenId, uint256 amount);

  event CollectFeeToTreasury(address indexed to, uint256 amountToCollect);

  struct YieldNftConfig {
    bool isActive;
    uint16 leverageFactor; // e.g. 50000 -> 500%
    uint16 collateralFactor; // e.g. 9000 -> 90%
    uint256 maxUnstakeFine; // e.g. In underlying asset's decimals
    uint256 unstakeHeathFactor; // 18 decimals, e.g. 1.0 -> 1e18
  }

  struct YieldStakeData {
    address yieldAccount;
    uint32 poolId;
    uint8 state;
    uint256 debtShare;
    uint256 wusdStakingPoolId;
    uint256 stakingPlanId;
    uint256 unstakeFine;
    uint256 withdrawAmount;
    uint256 remainYieldAmount;
  }

  uint48 public constant SECONDS_OF_YEAR = 31536000;
  uint256 constant DENOMINATOR = 1e6;

  IAddressProvider public addressProvider;
  IPoolManager public poolManager;
  IYield public poolYield;
  IYieldRegistry public yieldRegistry;
  IERC20Metadata public underlyingAsset;
  IWUSDStaking public wusdStaking;
  address public botAdmin;
  uint256 public totalDebtShare;
  uint256 public totalUnstakeFine;
  mapping(address => address) public yieldAccounts;
  mapping(address => YieldNftConfig) public nftConfigs;
  mapping(address => mapping(uint256 => YieldStakeData)) public stakeDatas;
  uint256 public claimedUnstakeFine;

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

  constructor() {
    _disableInitializers();
  }

  function initialize(address addressProvider_, address wusd_, address wusdStaking_) public initializer {
    __Pausable_init();
    __ReentrancyGuard_init();

    addressProvider = IAddressProvider(addressProvider_);

    poolManager = IPoolManager(addressProvider.getPoolManager());
    poolYield = IYield(addressProvider.getPoolModuleProxy(Constants.MODULEID__YIELD));
    yieldRegistry = IYieldRegistry(addressProvider.getYieldRegistry());

    underlyingAsset = IERC20Metadata(wusd_);
    wusdStaking = IWUSDStaking(wusdStaking_);

    underlyingAsset.safeApprove(address(poolManager), type(uint256).max);
  }

  /****************************************************************************/
  /* Configure Methods */
  /****************************************************************************/

  function setNftActive(address nft, bool active) public virtual onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.isActive = active;

    emit SetNftActive(nft, active);
  }

  function setNftStakeParams(address nft, uint16 leverageFactor, uint16 collateralFactor) public virtual onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.leverageFactor = leverageFactor;
    nc.collateralFactor = collateralFactor;

    emit SetNftStakeParams(nft, leverageFactor, collateralFactor);
  }

  function setNftUnstakeParams(
    address nft,
    uint256 maxUnstakeFine,
    uint256 unstakeHeathFactor
  ) public virtual onlyPoolAdmin {
    YieldNftConfig storage nc = nftConfigs[nft];
    nc.maxUnstakeFine = maxUnstakeFine;
    nc.unstakeHeathFactor = unstakeHeathFactor;

    emit SetNftUnstakeParams(nft, maxUnstakeFine, unstakeHeathFactor);
  }

  function setBotAdmin(address newAdmin) public virtual onlyPoolAdmin {
    require(newAdmin != address(0), Errors.INVALID_ADDRESS);

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

  function collectFeeToTreasury() public virtual onlyPoolAdmin {
    address to = addressProvider.getTreasury();
    require(to != address(0), Errors.TREASURY_CANNOT_BE_ZERO);

    if (totalUnstakeFine > claimedUnstakeFine) {
      uint256 amountToCollect = totalUnstakeFine - claimedUnstakeFine;
      claimedUnstakeFine += amountToCollect;

      underlyingAsset.safeTransfer(to, amountToCollect);

      emit CollectFeeToTreasury(to, amountToCollect);
    }
  }

  /****************************************************************************/
  /* Service Methods */
  /****************************************************************************/

  function createYieldAccount(address user) public virtual returns (address) {
    require(user != address(0), Errors.INVALID_ADDRESS);
    require(yieldAccounts[user] == address(0), Errors.YIELD_ACCOUNT_ALREADY_EXIST);

    address account = yieldRegistry.createYieldAccount(address(this));
    yieldAccounts[user] = account;

    IYieldAccount yieldAccount = IYieldAccount(account);
    yieldAccount.safeApprove(address(underlyingAsset), address(wusdStaking), type(uint256).max);

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
  }

  function batchStake(
    uint32 poolId,
    address[] calldata nfts,
    uint256[] calldata tokenIds,
    uint256[] calldata borrowAmounts,
    uint256 wusdStakingPoolId
  ) public virtual whenNotPaused nonReentrant {
    require(nfts.length == tokenIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);
    require(nfts.length == borrowAmounts.length, Errors.INCONSISTENT_PARAMS_LENGTH);

    for (uint i = 0; i < nfts.length; i++) {
      _stake(poolId, nfts[i], tokenIds[i], borrowAmounts[i], wusdStakingPoolId);
    }
  }

  function stake(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 borrowAmount,
    uint256 wusdStakingPoolId
  ) public virtual whenNotPaused nonReentrant {
    _stake(poolId, nft, tokenId, borrowAmount, wusdStakingPoolId);
  }

  function _stake(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 borrowAmount,
    uint256 wusdStakingPoolId
  ) internal virtual {
    StakeLocalVars memory vars;

    require(borrowAmount > 0, Errors.INVALID_AMOUNT);

    vars.yieldAccout = IYieldAccount(yieldAccounts[msg.sender]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    YieldNftConfig storage nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);
    require(nc.leverageFactor > 0, Errors.YIELD_ETH_NFT_LEVERAGE_FACTOR_ZERO);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);

    // only one staking plan for each nft
    require(vars.nftLockerAddr == address(0), Errors.YIELD_ETH_NFT_ALREADY_USED);

    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    require(sd.yieldAccount == address(0), Errors.YIELD_ETH_NFT_ALREADY_USED);

    sd.yieldAccount = address(vars.yieldAccout);
    sd.poolId = poolId;
    sd.state = Constants.YIELD_STATUS_ACTIVE;
    sd.wusdStakingPoolId = wusdStakingPoolId;

    vars.totalDebtAmount = borrowAmount;

    vars.nftPriceInUnderlyingAsset = getNftPriceInUnderlyingAsset(nft);
    vars.maxBorrowAmount = vars.nftPriceInUnderlyingAsset.percentMul(nc.leverageFactor);
    require(vars.totalDebtAmount <= vars.maxBorrowAmount, Errors.YIELD_ETH_EXCEED_MAX_BORROWABLE);

    // calculate debt share before borrow
    vars.debtShare = convertToDebtShares(poolId, borrowAmount);

    // borrow from lending pool
    poolYield.yieldBorrowERC20(poolId, address(underlyingAsset), borrowAmount);

    // stake in protocol and got the yield
    protocolDeposit(sd, borrowAmount);

    // update nft shares
    sd.debtShare += vars.debtShare;

    // update global shares
    totalDebtShare += vars.debtShare;

    poolYield.yieldSetERC721TokenData(poolId, nft, tokenId, true, address(underlyingAsset));

    // check hf
    uint256 hf = calculateHealthFactor(nft, nc, sd);
    require(hf >= nc.unstakeHeathFactor, Errors.YIELD_ETH_HEATH_FACTOR_TOO_LOW);

    emit Stake(msg.sender, nft, tokenId, borrowAmount);
  }

  struct UnstakeLocalVars {
    IYieldAccount yieldAccout;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
  }

  function batchUnstake(
    uint32 poolId,
    address[] calldata nfts,
    uint256[] calldata tokenIds,
    uint256 unstakeFine
  ) public virtual whenNotPaused nonReentrant {
    require(nfts.length == tokenIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);

    for (uint i = 0; i < nfts.length; i++) {
      _unstake(poolId, nfts[i], tokenIds[i], unstakeFine);
    }
  }

  function unstake(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 unstakeFine
  ) public virtual whenNotPaused nonReentrant {
    _unstake(poolId, nft, tokenId, unstakeFine);
  }

  function _unstake(uint32 poolId, address nft, uint256 tokenId, uint256 unstakeFine) internal virtual {
    UnstakeLocalVars memory vars;

    YieldNftConfig storage nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_NFT_NOT_USED_BY_ME);

    vars.yieldAccout = IYieldAccount(yieldAccounts[vars.nftOwner]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

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
    (sd.withdrawAmount, ) = _getNftYieldInUnderlyingAsset(sd, true);

    protocolRequestWithdrawal(sd);

    emit Unstake(vars.nftOwner, nft, tokenId, sd.withdrawAmount);
  }

  struct RepayLocalVars {
    IYieldAccount yieldAccout;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256 nftDebt;
    uint256 remainAmount;
    uint256 extraAmount;
    uint256 repaidNftDebt;
    uint256 repaidDebtShare;
  }

  function batchRepay(
    uint32 poolId,
    address[] calldata nfts,
    uint256[] calldata tokenIds
  ) public virtual whenNotPaused nonReentrant {
    require(nfts.length == tokenIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);

    for (uint i = 0; i < nfts.length; i++) {
      _repay(poolId, nfts[i], tokenIds[i]);
    }
  }

  function repay(uint32 poolId, address nft, uint256 tokenId) public virtual whenNotPaused nonReentrant {
    _repay(poolId, nft, tokenId);
  }

  function _repay(uint32 poolId, address nft, uint256 tokenId) internal virtual {
    RepayLocalVars memory vars;

    YieldNftConfig memory nc = nftConfigs[nft];
    require(nc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    require(
      sd.state == Constants.YIELD_STATUS_UNSTAKE || sd.state == Constants.YIELD_STATUS_CLAIM,
      Errors.YIELD_ETH_STATUS_NOT_UNSTAKE
    );
    require(sd.poolId == poolId, Errors.YIELD_ETH_POOL_NOT_SAME);

    // check the nft ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_NFT_NOT_USED_BY_ME);

    vars.yieldAccout = IYieldAccount(yieldAccounts[vars.nftOwner]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    // withdraw yield from protocol
    if (sd.state == Constants.YIELD_STATUS_UNSTAKE) {
      require(protocolIsClaimReady(sd), Errors.YIELD_ETH_WITHDRAW_NOT_READY);

      sd.remainYieldAmount = protocolClaimWithdraw(sd);

      sd.state = Constants.YIELD_STATUS_CLAIM;
    }

    vars.nftDebt = _getNftDebtInUnderlyingAsset(sd);

    /* 
    case 1: yield >= debt + fine can repay full by bot;
    case 2: yield > debt but can not cover the fine, need user do the repay;
    case 3: yield < debt, need user do the repay;

    bot admin will try to repay debt asap, to reduce the debt interest;
    */

    // compute repay value
    if (sd.remainYieldAmount >= vars.nftDebt) {
      vars.repaidNftDebt = vars.nftDebt;
      vars.repaidDebtShare = sd.debtShare;

      vars.remainAmount = sd.remainYieldAmount - vars.nftDebt;
      // vars.extraAmount = 0;
    } else {
      if (msg.sender == botAdmin) {
        // bot admin only repay debt from yield
        vars.repaidNftDebt = sd.remainYieldAmount;
        vars.repaidDebtShare = convertToDebtShares(poolId, vars.repaidNftDebt);
      } else {
        // sender (owner) must repay all debt
        vars.repaidNftDebt = vars.nftDebt;
        vars.repaidDebtShare = sd.debtShare;
      }

      // vars.remainAmount = 0;
      vars.extraAmount = vars.nftDebt - sd.remainYieldAmount;
    }

    // compute fine value
    if (vars.remainAmount >= sd.unstakeFine) {
      vars.remainAmount = vars.remainAmount - sd.unstakeFine;
    } else {
      vars.extraAmount = vars.extraAmount + (sd.unstakeFine - vars.remainAmount);
    }

    sd.remainYieldAmount = vars.remainAmount;

    // transfer eth from sender exclude bot admin
    if ((vars.extraAmount > 0) && (msg.sender != botAdmin)) {
      underlyingAsset.safeTransferFrom(msg.sender, address(this), vars.extraAmount);
    }

    // repay debt to lending pool
    if (vars.repaidNftDebt > 0) {
      poolYield.yieldRepayERC20(poolId, address(underlyingAsset), vars.repaidNftDebt);
    }

    // update shares
    sd.debtShare -= vars.repaidDebtShare;
    totalDebtShare -= vars.repaidDebtShare;

    // unlock nft when repaid all debt and fine
    if (msg.sender == botAdmin) {
      if ((sd.debtShare > 0) || (vars.extraAmount > 0)) {
        emit RepayPart(msg.sender, nft, tokenId, vars.repaidNftDebt);
        return;
      }
    }

    // send remain funds to owner
    if (sd.remainYieldAmount > 0) {
      underlyingAsset.safeTransfer(vars.nftOwner, sd.remainYieldAmount);
      sd.remainYieldAmount = 0;
    }

    // unlock nft
    poolYield.yieldSetERC721TokenData(poolId, nft, tokenId, false, address(underlyingAsset));

    delete stakeDatas[nft][tokenId];

    emit Repay(vars.nftOwner, nft, tokenId, vars.nftDebt);
  }

  /****************************************************************************/
  /* Query Methods */
  /****************************************************************************/

  function getNftConfig(
    address nft
  )
    public
    view
    virtual
    returns (
      bool isActive,
      uint16 leverageFactor,
      uint16 collateralFactor,
      uint256 maxUnstakeFine,
      uint256 unstakeHeathFactor
    )
  {
    YieldNftConfig memory nc = nftConfigs[nft];
    return (nc.isActive, nc.leverageFactor, nc.collateralFactor, nc.maxUnstakeFine, nc.unstakeHeathFactor);
  }

  function getYieldAccount(address user) public view virtual returns (address) {
    return yieldAccounts[user];
  }

  function getTotalDebt(uint32 poolId) public view virtual returns (uint256) {
    return poolYield.getYieldERC20BorrowBalance(poolId, address(underlyingAsset), address(this));
  }

  function getNftValueInUnderlyingAsset(address nft) public view virtual returns (uint256) {
    YieldNftConfig storage nc = nftConfigs[nft];

    uint256 nftPrice = getNftPriceInUnderlyingAsset(nft);
    uint256 totalNftValue = nftPrice.percentMul(nc.collateralFactor);
    return totalNftValue;
  }

  function getNftDebtInUnderlyingAsset(address nft, uint256 tokenId) public view virtual returns (uint256) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return _getNftDebtInUnderlyingAsset(sd);
  }

  function getNftYieldInUnderlyingAsset(
    address nft,
    uint256 tokenId
  ) public view virtual returns (uint256 yieldAmount, uint256 yieldValue) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return _getNftYieldInUnderlyingAsset(sd, false);
  }

  function getNftCollateralData(
    address nft,
    uint256 tokenId
  ) public view virtual returns (uint256 totalCollateral, uint256 totalBorrow, uint256 availabeBorrow) {
    YieldNftConfig storage nc = nftConfigs[nft];

    uint256 nftPrice = getNftPriceInUnderlyingAsset(nft);

    totalCollateral = nftPrice.percentMul(nc.collateralFactor);
    availabeBorrow = nftPrice.percentMul(nc.leverageFactor);

    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    totalBorrow = _getNftDebtInUnderlyingAsset(sd);

    if (availabeBorrow > totalBorrow) {
      availabeBorrow = availabeBorrow - totalBorrow;
    } else {
      availabeBorrow = 0;
    }
  }

  function getNftCollateralDataList(
    address[] calldata nfts,
    uint256[] calldata tokenIds
  )
    public
    view
    virtual
    returns (uint256[] memory totalCollaterals, uint256[] memory totalBorrows, uint256[] memory availabeBorrows)
  {
    totalCollaterals = new uint256[](nfts.length);
    totalBorrows = new uint256[](nfts.length);
    availabeBorrows = new uint256[](nfts.length);

    for (uint i = 0; i < nfts.length; i++) {
      (totalCollaterals[i], totalBorrows[i], availabeBorrows[i]) = getNftCollateralData(nfts[i], tokenIds[i]);
    }
  }

  function getNftStakeData(
    address nft,
    uint256 tokenId
  ) public view virtual returns (uint32 poolId, uint8 state, uint256 debtAmount, uint256 yieldAmount) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];

    state = sd.state;
    if (sd.state == Constants.YIELD_STATUS_UNSTAKE) {
      if (protocolIsClaimReady(sd)) {
        state = Constants.YIELD_STATUS_CLAIM;
      }
    }

    debtAmount = _getNftDebtInUnderlyingAsset(sd);

    if (sd.state == Constants.YIELD_STATUS_ACTIVE) {
      (yieldAmount, ) = _getNftYieldInUnderlyingAsset(sd, false);
    } else {
      yieldAmount = sd.withdrawAmount;
    }

    return (sd.poolId, state, debtAmount, yieldAmount);
  }

  function getNftStakeDataList(
    address[] calldata nfts,
    uint256[] calldata tokenIds
  )
    public
    view
    virtual
    returns (
      uint32[] memory poolIds,
      uint8[] memory states,
      uint256[] memory debtAmounts,
      uint256[] memory yieldAmounts
    )
  {
    poolIds = new uint32[](nfts.length);
    states = new uint8[](nfts.length);
    debtAmounts = new uint256[](nfts.length);
    yieldAmounts = new uint256[](nfts.length);

    for (uint i = 0; i < nfts.length; i++) {
      (poolIds[i], states[i], debtAmounts[i], yieldAmounts[i]) = getNftStakeData(nfts[i], tokenIds[i]);
    }
  }

  function getNftUnstakeData(
    address nft,
    uint256 tokenId
  ) public view virtual returns (uint256 unstakeFine, uint256 withdrawAmount, uint256 withdrawReqId) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return (sd.unstakeFine, sd.withdrawAmount, sd.stakingPlanId);
  }

  function getNftUnstakeDataList(
    address[] calldata nfts,
    uint256[] calldata tokenIds
  )
    public
    view
    virtual
    returns (uint256[] memory unstakeFines, uint256[] memory withdrawAmounts, uint256[] memory withdrawReqIds)
  {
    unstakeFines = new uint256[](nfts.length);
    withdrawAmounts = new uint256[](nfts.length);
    withdrawReqIds = new uint256[](nfts.length);

    for (uint i = 0; i < nfts.length; i++) {
      (unstakeFines[i], withdrawAmounts[i], withdrawReqIds[i]) = getNftUnstakeData(nfts[i], tokenIds[i]);
    }
  }

  function getTotalUnstakeFine() public view virtual returns (uint256 totalFine, uint256 claimedFine) {
    return (totalUnstakeFine, claimedUnstakeFine);
  }

  function getNftYieldStakeDataStruct(
    address nft,
    uint256 tokenId
  ) public view virtual returns (YieldStakeData memory) {
    return stakeDatas[nft][tokenId];
  }

  function getWUSDStakingPools()
    public
    view
    virtual
    returns (
      uint256[] memory stakingPoolIds,
      uint48[] memory stakingPeriods,
      uint256[] memory apys,
      uint256[] memory minStakingAmounts
    )
  {
    IWUSDStaking.StakingPoolDetail[] memory stakingPoolsDetails = wusdStaking.getGeneralStaking();

    stakingPoolIds = new uint256[](stakingPoolsDetails.length);
    stakingPeriods = new uint48[](stakingPoolsDetails.length);
    apys = new uint256[](stakingPoolsDetails.length);
    minStakingAmounts = new uint256[](stakingPoolsDetails.length);
    for (uint i = 0; i < stakingPoolsDetails.length; i++) {
      stakingPoolIds[i] = stakingPoolsDetails[i].stakingPoolId;
      stakingPeriods[i] = stakingPoolsDetails[i].stakingPool.stakingPeriod;
      apys[i] = stakingPoolsDetails[i].stakingPool.apy;
      minStakingAmounts[i] = stakingPoolsDetails[i].stakingPool.minStakingAmount;
    }
  }

  function getWUSDStakingPlan(
    address nft,
    uint256 tokenId
  ) public view virtual returns (IWUSDStaking.StakingPlan memory) {
    YieldStakeData storage sd = stakeDatas[nft][tokenId];
    return wusdStaking.getUserStakingPlan(sd.yieldAccount, sd.stakingPlanId);
  }

  /****************************************************************************/
  /* Internal Methods */
  /****************************************************************************/
  function protocolDeposit(YieldStakeData storage sd, uint256 amount) internal virtual returns (uint256) {
    IYieldAccount yieldAccount = IYieldAccount(sd.yieldAccount);

    underlyingAsset.safeTransfer(address(yieldAccount), amount);

    bytes memory result = yieldAccount.execute(
      address(wusdStaking),
      abi.encodeWithSelector(IWUSDStaking.stake.selector, sd.wusdStakingPoolId, amount)
    );
    sd.stakingPlanId = abi.decode(result, (uint256));
    require(sd.stakingPlanId > 0, Errors.YIELD_ETH_DEPOSIT_FAILED);

    return amount;
  }

  function protocolRequestWithdrawal(YieldStakeData storage sd) internal virtual {
    // check the end time of staking plan
    IWUSDStaking.StakingPlan memory stakingPlan = wusdStaking.getUserStakingPlan(sd.yieldAccount, sd.stakingPlanId);
    if (uint256(stakingPlan.endTime) >= block.timestamp) {
      IYieldAccount yieldAccount = IYieldAccount(sd.yieldAccount);
      yieldAccount.execute(
        address(wusdStaking),
        abi.encodeWithSelector(IWUSDStaking.terminate.selector, sd.stakingPlanId)
      );
    }
  }

  function protocolClaimWithdraw(YieldStakeData storage sd) internal virtual returns (uint256) {
    IYieldAccount yieldAccount = IYieldAccount(sd.yieldAccount);

    uint256 claimedAmount = underlyingAsset.balanceOf(address(yieldAccount));
    uint256[] memory stakingPlanIds = new uint256[](1);
    stakingPlanIds[0] = sd.stakingPlanId;
    yieldAccount.execute(address(wusdStaking), abi.encodeWithSelector(IWUSDStaking.claim.selector, stakingPlanIds));
    claimedAmount = underlyingAsset.balanceOf(address(yieldAccount)) - claimedAmount;
    require(claimedAmount > 0, Errors.YIELD_ETH_CLAIM_FAILED);

    yieldAccount.safeTransfer(address(underlyingAsset), address(this), claimedAmount);

    return claimedAmount;
  }

  function protocolIsClaimReady(YieldStakeData storage sd) internal view virtual returns (bool) {
    if (sd.state == Constants.YIELD_STATUS_CLAIM) {
      return true;
    }

    if (sd.state == Constants.YIELD_STATUS_UNSTAKE) {
      IWUSDStaking.StakingPlan memory stakingPlan = wusdStaking.getUserStakingPlan(sd.yieldAccount, sd.stakingPlanId);
      uint48 currentTime = uint48(block.timestamp);

      if (stakingPlan.stakingStatus == IWUSDStaking.StakingStatus.CLAIMABLE) {
        // mannually terminate the plan before end time of mature
        if (currentTime >= stakingPlan.claimableTimestamp) {
          return true;
        }
      } else if (stakingPlan.endTime <= currentTime) {
        // directly claim after end time of mature
        return true;
      }
    }

    return false;
  }

  function convertToDebtShares(uint32 poolId, uint256 assets) public view virtual returns (uint256) {
    return assets.convertToShares(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function convertToDebtAssets(uint32 poolId, uint256 shares) public view virtual returns (uint256) {
    return shares.convertToAssets(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function _getNftDebtInUnderlyingAsset(YieldStakeData storage sd) internal view virtual returns (uint256) {
    return convertToDebtAssets(sd.poolId, sd.debtShare);
  }

  function _getNftYieldInUnderlyingAsset(
    YieldStakeData storage sd,
    bool isUnstake
  ) internal view virtual returns (uint256, uint256) {
    IWUSDStaking.StakingPlan memory stakingPlan = wusdStaking.getUserStakingPlan(sd.yieldAccount, sd.stakingPlanId);

    // there's no yield token for WUSD staking, just the same token
    // the yield amount here should include the pricipal and rewards
    // the under amount is same with yield amount
    uint256 yieldAmount = stakingPlan.stakedAmount;

    uint48 calcEndTime;
    uint256 calcAPY;
    if (block.timestamp >= stakingPlan.endTime) {
      calcEndTime = stakingPlan.endTime;
      calcAPY = stakingPlan.apy;
    } else {
      calcEndTime = uint48(block.timestamp);
      if (isUnstake) {
        calcAPY = wusdStaking.getBasicAPY();
      } else {
        calcAPY = stakingPlan.apy;
      }
    }
    yieldAmount += _calculateYield(stakingPlan.stakedAmount, calcAPY, calcEndTime - stakingPlan.startTime);

    return (yieldAmount, yieldAmount);
  }

  function getProtocolTokenDecimals() internal view virtual returns (uint8) {
    return 6;
  }

  function getProtocolTokenPriceInUnderlyingAsset() internal view virtual returns (uint256) {
    return 1e6;
  }

  function getProtocolTokenAmountInUnderlyingAsset(uint256 yieldAmount) internal view virtual returns (uint256) {
    // WUSD is not rebase model, the share are fixed
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
    uint256 totalNftValue = nftPrice.percentMul(nc.collateralFactor);

    (, uint256 totalYieldValue) = _getNftYieldInUnderlyingAsset(sd, false);
    uint256 totalDebtValue = _getNftDebtInUnderlyingAsset(sd);

    return (totalNftValue + totalYieldValue).wadDiv(totalDebtValue);
  }

  function _calculateYield(
    uint256 stakedAmount,
    uint256 apy,
    uint48 stakingDuration
  ) internal pure virtual returns (uint256) {
    return (stakedAmount * apy * stakingDuration) / SECONDS_OF_YEAR / DENOMINATOR;
  }
}
