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

abstract contract YieldStakingBaseV2 is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20Metadata;
  using PercentageMath for uint256;
  using ShareUtils for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;
  using Math for uint256;

  event SetCollateralActive(address indexed collateral, uint8 assetType, bool isActive);
  event SetCollateralStakeParams(address indexed collateral, uint16 leverageFactor, uint16 collateralFactor);
  event SetCollateralUnstakeParams(address indexed collateral, uint256 maxUnstakeFine, uint256 unstakeHeathFactor);
  event SetBotAdmin(address oldAdmin, address newAdmin);

  event StakeERC721(
    address indexed user,
    address indexed nft,
    uint256 indexed tokenId,
    uint256 amount,
    uint256 stakeId
  );
  event UnstakeERC721(
    address indexed user,
    address indexed nft,
    uint256 indexed tokenId,
    uint256 amount,
    uint256 stakeId
  );
  event RepayERC721(
    address indexed user,
    address indexed nft,
    uint256 indexed tokenId,
    uint256 amount,
    uint256 stakeId
  );
  event RepayPartERC721(
    address indexed user,
    address indexed nft,
    uint256 indexed tokenId,
    uint256 amount,
    uint256 stakeId
  );

  event StakeERC20(address indexed user, address indexed asset, uint256 amount, uint256 stakeId);
  event UnstakeERC20(address indexed user, address indexed asset, uint256 amount, uint256 stakeId);
  event RepayERC20(address indexed user, address indexed asset, uint256 amount, uint256 stakeId);
  event RepayPartERC20(address indexed user, address indexed asset, uint256 amount, uint256 stakeId);

  event CollectFeeToTreasury(address indexed to, uint256 amountToCollect);

  struct YieldCollateralConfig {
    uint8 assetType;
    bool isActive;
    uint16 leverageFactor; // e.g. 50000 -> 500%
    uint16 collateralFactor; // e.g. 9000 -> 90%
    uint256 maxUnstakeFine; // e.g. In underlying asset's decimals
    uint256 unstakeHeathFactor; // 18 decimals, e.g. 1.0 -> 1e18
  }

  struct YieldStakeData {
    uint32 poolId;
    uint8 state;
    address stakeOwner;
    address collateralAsset;
    uint256 collateralAmount;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 unstakeFine;
    uint256 withdrawAmount;
    uint256 withdrawReqId;
    uint256 remainYieldAmount;
  }

  IAddressProvider public addressProvider;
  IPoolManager public poolManager;
  IYield public poolYield;
  IYieldRegistry public yieldRegistry;
  IERC20Metadata public debtAsset; // WUSD
  IERC20Metadata public yieldAsset; // USDE
  address public botAdmin;
  uint256 public totalUnstakeFine;
  uint256 public claimedUnstakeFine;
  uint256 public totalDebtShare;
  mapping(address => address) public yieldAccounts;
  mapping(address => uint256) public accountYieldShares;
  mapping(address => uint256) public accountYieldInWithdraws;
  mapping(address => YieldCollateralConfig) public collateralConfigs;
  uint256 public stakeIdCounter;
  mapping(address => mapping(uint256 => uint256)) public nftToken2StakeIds;
  mapping(uint256 => YieldStakeData) public stakeDatas;

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

  function __YieldStakingBase_init(
    address addressProvider_,
    address debtAsset_,
    address yieldAsset_
  ) internal onlyInitializing {
    __Pausable_init();
    __ReentrancyGuard_init();

    addressProvider = IAddressProvider(addressProvider_);

    poolManager = IPoolManager(addressProvider.getPoolManager());
    poolYield = IYield(addressProvider.getPoolModuleProxy(Constants.MODULEID__YIELD));
    yieldRegistry = IYieldRegistry(addressProvider.getYieldRegistry());

    debtAsset = IERC20Metadata(debtAsset_);
    yieldAsset = IERC20Metadata(yieldAsset_);

    debtAsset.safeApprove(address(poolManager), type(uint256).max);
  }

  /****************************************************************************/
  /* Configure Methods */
  /****************************************************************************/

  function setCollateralActive(address collateral, uint8 assetType, bool active) public virtual onlyPoolAdmin {
    YieldCollateralConfig storage cfg = collateralConfigs[collateral];
    cfg.assetType = assetType;
    cfg.isActive = active;

    emit SetCollateralActive(collateral, assetType, active);
  }

  function setCollateralStakeParams(
    address collateral,
    uint16 leverageFactor,
    uint16 collateralFactor
  ) public virtual onlyPoolAdmin {
    YieldCollateralConfig storage cfg = collateralConfigs[collateral];
    cfg.leverageFactor = leverageFactor;
    cfg.collateralFactor = collateralFactor;

    emit SetCollateralStakeParams(collateral, leverageFactor, collateralFactor);
  }

  function setCollateralUnstakeParams(
    address collateral,
    uint256 maxUnstakeFine,
    uint256 unstakeHeathFactor
  ) public virtual onlyPoolAdmin {
    YieldCollateralConfig storage cfg = collateralConfigs[collateral];
    cfg.maxUnstakeFine = maxUnstakeFine;
    cfg.unstakeHeathFactor = unstakeHeathFactor;

    emit SetCollateralUnstakeParams(collateral, maxUnstakeFine, unstakeHeathFactor);
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

      debtAsset.safeTransfer(to, amountToCollect);

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
    return account;
  }

  struct StakeLocalVars {
    IYieldAccount yieldAccout;
    address collateralAsset;
    uint256 stakeId;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256 totalDebtAmount;
    uint256 colValueInDebtAsset;
    uint256 maxBorrowAmount;
    uint256 debtShare;
    uint256 yieldShare;
    uint256 yieldAmount;
    uint256 totalYieldBeforeDeposit;
  }

  function batchStakeERC721(
    uint32 poolId,
    address[] calldata nfts,
    uint256[] calldata tokenIds,
    uint256[] calldata borrowAmounts
  ) public virtual whenNotPaused nonReentrant returns (uint256[] memory stakeIds) {
    require(nfts.length == tokenIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);
    require(nfts.length == borrowAmounts.length, Errors.INCONSISTENT_PARAMS_LENGTH);

    stakeIds = new uint256[](tokenIds.length);
    for (uint i = 0; i < tokenIds.length; i++) {
      _stakeERC721(poolId, nfts[i], tokenIds[i], borrowAmounts[i]);
    }
  }

  function stakeERC721(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 borrowAmount
  ) public virtual whenNotPaused nonReentrant returns (uint256 stakeId) {
    stakeId = _stakeERC721(poolId, nft, tokenId, borrowAmount);
  }

  function _stakeERC721(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 borrowAmount
  ) internal virtual returns (uint256 stakeId) {
    StakeLocalVars memory vars;
    vars.collateralAsset = nft;

    vars.stakeId = nftToken2StakeIds[nft][tokenId];
    require(vars.stakeId == 0, Errors.YIELD_ETH_NFT_ALREADY_USED);

    // check the ownership and only stake once per nft item
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(0), Errors.YIELD_ETH_NFT_ALREADY_USED);

    // get the unique stake id
    vars.stakeId = ++stakeIdCounter;
    nftToken2StakeIds[nft][tokenId] = vars.stakeId;

    _stakeCore(vars, poolId, nft, 1, borrowAmount);

    // lock the nft used in this stake
    poolYield.yieldSetERC721TokenData(poolId, nft, tokenId, true, address(debtAsset));

    emit StakeERC721(msg.sender, nft, tokenId, borrowAmount, vars.stakeId);

    return vars.stakeId;
  }

  function stakeERC20(
    uint32 poolId,
    address collateralAsset,
    uint256 collateralAmount,
    uint256 borrowAmount
  ) public virtual whenNotPaused nonReentrant returns (uint256 stakeId) {
    StakeLocalVars memory vars;
    vars.collateralAsset = collateralAsset;

    // don't check the supply and locked amount at here, reduce gas
    // poolYield.getERC20TokenData(poolId, collateralAsset, msg.sender, address(this));

    // get the unique stake id
    vars.stakeId = ++stakeIdCounter;

    _stakeCore(vars, poolId, collateralAsset, collateralAmount, borrowAmount);

    // this set method will check the supply and locked amount
    poolYield.yieldSetERC20TokenData(poolId, collateralAsset, collateralAmount, msg.sender, true, address(debtAsset));

    emit StakeERC20(msg.sender, collateralAsset, borrowAmount, vars.stakeId);

    return vars.stakeId;
  }

  function _stakeCore(
    StakeLocalVars memory vars,
    uint32 poolId,
    address collateralAsset,
    uint256 collateralAmount,
    uint256 borrowAmount
  ) internal virtual {
    require(collateralAmount > 0, Errors.INVALID_AMOUNT);
    require(borrowAmount > 0, Errors.INVALID_AMOUNT);

    // check the yeild acount must be exist
    vars.yieldAccout = IYieldAccount(yieldAccounts[msg.sender]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    // check collateral config
    YieldCollateralConfig storage cc = collateralConfigs[collateralAsset];
    require(cc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);
    require(cc.leverageFactor > 0, Errors.YIELD_ETH_NFT_LEVERAGE_FACTOR_ZERO);

    vars.totalDebtAmount = borrowAmount;
    vars.colValueInDebtAsset = getCollateralValueInDebtAsset(cc.assetType, collateralAsset, collateralAmount);
    vars.maxBorrowAmount = vars.colValueInDebtAsset.percentMul(cc.leverageFactor);
    require(vars.totalDebtAmount <= vars.maxBorrowAmount, Errors.YIELD_ETH_EXCEED_MAX_BORROWABLE);

    // calculate debt share before borrow
    vars.debtShare = convertToDebtShares(poolId, borrowAmount);

    YieldStakeData storage sd = stakeDatas[vars.stakeId];
    sd.stakeOwner = msg.sender;
    sd.poolId = poolId;
    sd.state = Constants.YIELD_STATUS_ACTIVE;

    // borrow from lending pool
    poolYield.yieldBorrowERC20(poolId, address(debtAsset), borrowAmount);

    // stake in protocol and got the yield
    vars.totalYieldBeforeDeposit = getAccountTotalUnstakedYield(address(vars.yieldAccout));
    vars.yieldAmount = protocolDeposit(sd, borrowAmount);
    vars.yieldShare = _convertToYieldSharesWithTotalYield(
      address(vars.yieldAccout),
      vars.yieldAmount,
      vars.totalYieldBeforeDeposit
    );

    // update stake shares
    sd.debtShare += vars.debtShare;
    sd.yieldShare += vars.yieldShare;

    // update global shares
    totalDebtShare += vars.debtShare;
    accountYieldShares[address(vars.yieldAccout)] += vars.yieldShare;

    // check hf
    uint256 hf = calculateHealthFactor(cc, sd);
    require(hf >= cc.unstakeHeathFactor, Errors.YIELD_ETH_HEATH_FACTOR_TOO_LOW);
  }

  struct UnstakeLocalVars {
    IYieldAccount yieldAccout;
    uint256 stakeId;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256[] requestAmounts;
  }

  function batchUnstakeERC721(
    uint32 poolId,
    address[] calldata nfts,
    uint256[] calldata tokenIds,
    uint256 unstakeFine
  ) public virtual whenNotPaused nonReentrant {
    require(nfts.length == tokenIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);

    for (uint i = 0; i < nfts.length; i++) {
      _unstakeERC721(poolId, nfts[i], tokenIds[i], unstakeFine);
    }
  }

  function unstakeERC721(
    uint32 poolId,
    address nft,
    uint256 tokenId,
    uint256 unstakeFine
  ) public virtual whenNotPaused nonReentrant {
    _unstakeERC721(poolId, nft, tokenId, unstakeFine);
  }

  function _unstakeERC721(uint32 poolId, address nft, uint256 tokenId, uint256 unstakeFine) internal virtual {
    UnstakeLocalVars memory vars;

    // check the ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_NFT_NOT_USED_BY_ME);

    vars.stakeId = nftToken2StakeIds[nft][tokenId];
    require(vars.stakeId != 0, Errors.YIELD_ETH_NFT_NOT_USED_BY_ME);

    YieldStakeData storage sd = stakeDatas[vars.stakeId];

    _unstakeCore(poolId, nft, unstakeFine);

    emit UnstakeERC721(sd.stakeOwner, nft, tokenId, sd.withdrawAmount, vars.stakeId);
  }

  function unstakeERC20(
    uint32 poolId,
    address collateralAsset,
    uint256 stakeId,
    uint256 unstakeFine
  ) public virtual whenNotPaused nonReentrant {
    UnstakeLocalVars memory vars;

    require(stakeId != 0, Errors.YIELD_ETH_NFT_NOT_USED_BY_ME);

    vars.stakeId = stakeId;
    YieldStakeData storage sd = stakeDatas[stakeId];

    _unstakeCore(poolId, collateralAsset, unstakeFine);

    emit UnstakeERC20(sd.stakeOwner, collateralAsset, sd.withdrawAmount, stakeId);
  }

  function _unstakeCore(uint32 poolId, address collateralAsset, uint256 unstakeFine) internal virtual {
    UnstakeLocalVars memory vars;

    YieldCollateralConfig storage cc = collateralConfigs[collateralAsset];
    require(cc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    vars.yieldAccout = IYieldAccount(yieldAccounts[vars.nftOwner]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    YieldStakeData storage sd = stakeDatas[vars.stakeId];
    require(sd.stakeOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(sd.state == Constants.YIELD_STATUS_ACTIVE, Errors.YIELD_ETH_STATUS_NOT_ACTIVE);
    require(sd.poolId == poolId, Errors.YIELD_ETH_POOL_NOT_SAME);

    // sender must be bot or owner
    if (msg.sender == botAdmin) {
      require(unstakeFine <= cc.maxUnstakeFine, Errors.YIELD_ETH_EXCEED_MAX_FINE);

      uint256 hf = calculateHealthFactor(cc, sd);
      require(hf < cc.unstakeHeathFactor, Errors.YIELD_ETH_HEATH_FACTOR_TOO_HIGH);

      sd.unstakeFine = unstakeFine;
      totalUnstakeFine += unstakeFine;
    }

    sd.state = Constants.YIELD_STATUS_UNSTAKE;
    sd.withdrawAmount = convertToYieldAssets(address(vars.yieldAccout), sd.yieldShare);
    accountYieldInWithdraws[address(vars.yieldAccout)] += sd.withdrawAmount;

    protocolRequestWithdrawal(sd);

    // update shares
    accountYieldShares[address(vars.yieldAccout)] -= sd.yieldShare;
    sd.yieldShare = 0;
  }

  struct RepayLocalVars {
    IYieldAccount yieldAccout;
    uint256 stakeId;
    address nftOwner;
    uint8 nftSupplyMode;
    address nftLockerAddr;
    uint256 nftDebt;
    uint256 remainAmount;
    uint256 extraAmount;
    uint256 repaidNftDebt;
    uint256 repaidDebtShare;
  }

  function batchRepayERC721(
    uint32 poolId,
    address[] calldata nfts,
    uint256[] calldata tokenIds
  ) public virtual whenNotPaused nonReentrant {
    require(nfts.length == tokenIds.length, Errors.INCONSISTENT_PARAMS_LENGTH);

    for (uint i = 0; i < nfts.length; i++) {
      _repayERC721(poolId, nfts[i], tokenIds[i]);
    }
  }

  function repayERC721(uint32 poolId, address nft, uint256 tokenId) public virtual whenNotPaused nonReentrant {
    _repayERC721(poolId, nft, tokenId);
  }

  function _repayERC721(uint32 poolId, address nft, uint256 tokenId) internal virtual {
    RepayLocalVars memory vars;

    // check the ownership
    (vars.nftOwner, vars.nftSupplyMode, vars.nftLockerAddr) = poolYield.getERC721TokenData(poolId, nft, tokenId);
    require(vars.nftOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(vars.nftSupplyMode == Constants.SUPPLY_MODE_ISOLATE, Errors.INVALID_SUPPLY_MODE);
    require(vars.nftLockerAddr == address(this), Errors.YIELD_ETH_NFT_NOT_USED_BY_ME);

    vars.stakeId = nftToken2StakeIds[nft][tokenId];

    bool isFullRepay = _repayCore(poolId, vars);
    if (!isFullRepay) {
      emit RepayPartERC721(msg.sender, nft, tokenId, vars.repaidNftDebt, vars.stakeId);
    } else {
      // unlock nft
      poolYield.yieldSetERC721TokenData(poolId, nft, tokenId, false, address(debtAsset));

      emit RepayERC721(vars.nftOwner, nft, tokenId, vars.nftDebt, vars.stakeId);
    }
  }

  function repayERC20(uint32 poolId, uint256 stakeId) public virtual whenNotPaused nonReentrant {
    RepayLocalVars memory vars;

    YieldStakeData storage sd = stakeDatas[stakeId];

    bool isFullRepay = _repayCore(poolId, vars);
    if (!isFullRepay) {
      emit RepayPartERC20(msg.sender, sd.collateralAsset, vars.repaidNftDebt, vars.stakeId);
    } else {
      // unlock erc20
      poolYield.yieldSetERC20TokenData(
        poolId,
        sd.collateralAsset,
        sd.collateralAmount,
        sd.stakeOwner,
        false,
        address(debtAsset)
      );

      emit RepayERC20(sd.stakeOwner, sd.collateralAsset, vars.nftDebt, vars.stakeId);
    }
  }

  function _repayCore(uint32 poolId, RepayLocalVars memory vars) internal virtual returns (bool isFull) {
    YieldStakeData storage sd = stakeDatas[vars.stakeId];

    YieldCollateralConfig memory cc = collateralConfigs[sd.collateralAsset];
    require(cc.isActive, Errors.YIELD_ETH_NFT_NOT_ACTIVE);

    require(sd.stakeOwner == msg.sender || botAdmin == msg.sender, Errors.INVALID_CALLER);
    require(
      sd.state == Constants.YIELD_STATUS_UNSTAKE || sd.state == Constants.YIELD_STATUS_CLAIM,
      Errors.YIELD_ETH_STATUS_NOT_UNSTAKE
    );
    require(sd.poolId == poolId, Errors.YIELD_ETH_POOL_NOT_SAME);

    vars.yieldAccout = IYieldAccount(yieldAccounts[vars.nftOwner]);
    require(address(vars.yieldAccout) != address(0), Errors.YIELD_ACCOUNT_NOT_EXIST);

    // withdraw yield from protocol
    if (sd.state == Constants.YIELD_STATUS_UNSTAKE) {
      require(protocolIsClaimReady(sd), Errors.YIELD_ETH_WITHDRAW_NOT_READY);

      sd.remainYieldAmount = protocolClaimWithdraw(sd);

      sd.state = Constants.YIELD_STATUS_CLAIM;
      accountYieldInWithdraws[address(vars.yieldAccout)] -= sd.withdrawAmount;
    }

    vars.nftDebt = _getDebtInDebtAsset(sd);

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
      debtAsset.safeTransferFrom(msg.sender, address(this), vars.extraAmount);
    }

    // repay debt to lending pool
    if (vars.repaidNftDebt > 0) {
      poolYield.yieldRepayERC20(poolId, address(debtAsset), vars.repaidNftDebt);
    }

    // update shares
    sd.debtShare -= vars.repaidDebtShare;
    totalDebtShare -= vars.repaidDebtShare;

    // bot can not repay full debt if yield not enough to cover the debt
    if (msg.sender == botAdmin) {
      if ((sd.debtShare > 0) || (vars.extraAmount > 0)) {
        return false;
      }
    }

    // send remain funds to owner
    if (sd.remainYieldAmount > 0) {
      debtAsset.safeTransfer(vars.nftOwner, sd.remainYieldAmount);
      sd.remainYieldAmount = 0;
    }

    delete stakeDatas[vars.stakeId];

    return true;
  }

  /****************************************************************************/
  /* Query Methods */
  /****************************************************************************/

  function getCollateralConfig(
    address collateral
  )
    public
    view
    virtual
    returns (
      uint8 assetType,
      bool isActive,
      uint16 leverageFactor,
      uint16 collateralFactor,
      uint256 maxUnstakeFine,
      uint256 unstakeHeathFactor
    )
  {
    YieldCollateralConfig memory cc = collateralConfigs[collateral];
    return (
      cc.assetType,
      cc.isActive,
      cc.leverageFactor,
      cc.collateralFactor,
      cc.maxUnstakeFine,
      cc.unstakeHeathFactor
    );
  }

  function getCollateralConfigStruct(address collateral) public view virtual returns (YieldCollateralConfig memory) {
    return collateralConfigs[collateral];
  }

  function getYieldAccount(address user) public view virtual returns (address) {
    return yieldAccounts[user];
  }

  function getTotalDebt(uint32 poolId) public view virtual returns (uint256) {
    return poolYield.getYieldERC20BorrowBalance(poolId, address(debtAsset), address(this));
  }

  function getAccountTotalYield(address account) public view virtual returns (uint256) {
    return getAccountYieldBalance(account);
  }

  function getAccountTotalUnstakedYield(address account) public view virtual returns (uint256) {
    return getAccountYieldBalance(account);
  }

  function getAccountYieldBalance(address account) public view virtual returns (uint256) {}

  function getCollateralInDebtAsset(uint256 stakeId) public view virtual returns (uint256) {
    YieldStakeData memory sd = stakeDatas[stakeId];
    YieldCollateralConfig memory cc = collateralConfigs[sd.collateralAsset];

    uint256 totalColValue = getCollateralValueInDebtAsset(cc.assetType, sd.collateralAsset, sd.collateralAmount);
    totalColValue = totalColValue.percentMul(cc.collateralFactor);
    return totalColValue;
  }

  function getDebtInDebtAsset(uint256 stakeId) public view virtual returns (uint256) {
    YieldStakeData memory sd = stakeDatas[stakeId];
    return _getDebtInDebtAsset(sd);
  }

  function getYieldInDebtAsset(uint256 stakeId) public view virtual returns (uint256 yieldAmount, uint256 yieldValue) {
    YieldStakeData memory sd = stakeDatas[stakeId];
    return _getYieldInDebtAsset(sd);
  }

  function getNftCollateralData(
    address nft,
    uint256 tokenId
  ) public view virtual returns (uint256 totalCollateral, uint256 totalBorrow, uint256 availabeBorrow) {
    YieldCollateralConfig memory cc = collateralConfigs[nft];

    totalCollateral = getCollateralValueInDebtAsset(cc.assetType, nft, 1);
    totalCollateral = totalCollateral.percentMul(cc.collateralFactor);

    availabeBorrow = totalCollateral.percentMul(cc.leverageFactor);

    uint256 stakeId = nftToken2StakeIds[nft][tokenId];
    YieldStakeData memory sd = stakeDatas[stakeId];
    totalBorrow = _getDebtInDebtAsset(sd);

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

  function getStakeData(
    uint256 stakeId
  ) public view virtual returns (uint32 poolId, uint8 state, uint256 debtAmount, uint256 yieldAmount) {
    YieldStakeData storage sd = stakeDatas[stakeId];

    state = sd.state;
    if (sd.state == Constants.YIELD_STATUS_UNSTAKE) {
      if (protocolIsClaimReady(sd)) {
        state = Constants.YIELD_STATUS_CLAIM;
      }
    }

    debtAmount = _getDebtInDebtAsset(sd);

    if (sd.state == Constants.YIELD_STATUS_ACTIVE) {
      (yieldAmount, ) = _getYieldInDebtAsset(sd);
    } else {
      yieldAmount = sd.withdrawAmount;
    }

    return (sd.poolId, state, debtAmount, yieldAmount);
  }

  function getNftStakeDataList(
    uint256[] calldata stakeIds
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
    poolIds = new uint32[](stakeIds.length);
    states = new uint8[](stakeIds.length);
    debtAmounts = new uint256[](stakeIds.length);
    yieldAmounts = new uint256[](stakeIds.length);

    for (uint i = 0; i < stakeIds.length; i++) {
      (poolIds[i], states[i], debtAmounts[i], yieldAmounts[i]) = getStakeData(stakeIds[i]);
    }
  }

  function getUnstakeData(
    uint256 stakeId
  ) public view virtual returns (uint256 unstakeFine, uint256 withdrawAmount, uint256 withdrawReqId) {
    YieldStakeData storage sd = stakeDatas[stakeId];
    return (sd.unstakeFine, sd.withdrawAmount, sd.withdrawReqId);
  }

  function getUnstakeDataList(
    uint256[] calldata stakeIds
  )
    public
    view
    virtual
    returns (uint256[] memory unstakeFines, uint256[] memory withdrawAmounts, uint256[] memory withdrawReqIds)
  {
    unstakeFines = new uint256[](stakeIds.length);
    withdrawAmounts = new uint256[](stakeIds.length);
    withdrawReqIds = new uint256[](stakeIds.length);

    for (uint i = 0; i < stakeIds.length; i++) {
      (unstakeFines[i], withdrawAmounts[i], withdrawReqIds[i]) = getUnstakeData(stakeIds[i]);
    }
  }

  function getTotalUnstakeFine() public view virtual returns (uint256 totalFine, uint256 claimedFine) {
    return (totalUnstakeFine, claimedUnstakeFine);
  }

  function getStakeDataStruct(uint256 stakeId) public view virtual returns (YieldStakeData memory) {
    YieldStakeData memory sd = stakeDatas[stakeId];
    return sd;
  }

  /****************************************************************************/
  /* Internal Methods */
  /****************************************************************************/
  function protocolDeposit(YieldStakeData storage sd, uint256 amount) internal virtual returns (uint256) {}

  function protocolRequestWithdrawal(YieldStakeData storage sd) internal virtual {}

  function protocolClaimWithdraw(YieldStakeData storage sd) internal virtual returns (uint256) {}

  function protocolIsClaimReady(YieldStakeData storage sd) internal view virtual returns (bool) {
    if (sd.state == Constants.YIELD_STATUS_CLAIM) {
      return true;
    }

    return false;
  }

  function convertToDebtShares(uint32 poolId, uint256 assets) public view virtual returns (uint256) {
    return assets.convertToShares(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function convertToDebtAssets(uint32 poolId, uint256 shares) public view virtual returns (uint256) {
    return shares.convertToAssets(totalDebtShare, getTotalDebt(poolId), Math.Rounding.Down);
  }

  function convertToYieldShares(address account, uint256 assets) public view virtual returns (uint256) {
    return
      assets.convertToShares(accountYieldShares[account], getAccountTotalUnstakedYield(account), Math.Rounding.Down);
  }

  function convertToYieldAssets(address account, uint256 shares) public view virtual returns (uint256) {
    return
      shares.convertToAssets(accountYieldShares[account], getAccountTotalUnstakedYield(account), Math.Rounding.Down);
  }

  function _convertToYieldSharesWithTotalYield(
    address account,
    uint256 assets,
    uint256 totalYield
  ) internal view virtual returns (uint256) {
    return assets.convertToShares(accountYieldShares[account], totalYield, Math.Rounding.Down);
  }

  function _getDebtInDebtAsset(YieldStakeData memory sd) internal view virtual returns (uint256) {
    return convertToDebtAssets(sd.poolId, sd.debtShare);
  }

  function _getYieldInDebtAsset(YieldStakeData memory sd) internal view virtual returns (uint256, uint256) {
    // here's yieldAmount are just the raw amount (shares) for the token in the protocol, not the actual underlying assets
    uint256 yieldAmount = convertToYieldAssets(yieldAccounts[sd.stakeOwner], sd.yieldShare);
    uint256 underAmount = getProtocolTokenAmountInDebtAsset(yieldAmount);

    // yieldValue are calculated by the raw amount & protocol token price
    uint256 yieldPrice = getProtocolTokenPriceInDebtAsset();
    return (underAmount, yieldAmount.mulDiv(yieldPrice, 10 ** getProtocolTokenDecimals()));
  }

  function getProtocolTokenDecimals() internal view virtual returns (uint8) {
    return 0;
  }

  function getProtocolTokenPriceInDebtAsset() internal view virtual returns (uint256) {
    return 0;
  }

  function getProtocolTokenAmountInDebtAsset(uint256 yieldAmount) internal view virtual returns (uint256) {
    // stETH, eETH is rebase model & 1:1 to the underlying
    // but sDAI is not rebase model, the share are fixed
    return yieldAmount;
  }

  function getCollateralPriceInDebtAsset(address collateralAsset) internal view virtual returns (uint256) {
    IPriceOracleGetter priceOracle = IPriceOracleGetter(addressProvider.getPriceOracle());
    uint256 colPriceInBase = priceOracle.getAssetPrice(collateralAsset);
    uint256 debtAssetPriceInBase = priceOracle.getAssetPrice(address(debtAsset));
    return colPriceInBase.mulDiv(10 ** debtAsset.decimals(), debtAssetPriceInBase);
  }

  function getCollateralValueInDebtAsset(
    uint8 assetType,
    address collateralAsset,
    uint256 collateralAmount
  ) internal view virtual returns (uint256) {
    uint256 colValueInDebtAsset = getCollateralPriceInDebtAsset(collateralAsset);

    if (assetType == Constants.ASSET_TYPE_ERC20) {
      return ((colValueInDebtAsset * collateralAmount) / (10 ** debtAsset.decimals()));
    } else if (assetType == Constants.ASSET_TYPE_ERC721) {
      return colValueInDebtAsset * collateralAmount;
    } else {
      return 0;
    }
  }

  function calculateHealthFactor(
    YieldCollateralConfig storage cc,
    YieldStakeData storage sd
  ) internal view virtual returns (uint256) {
    uint256 totalColValue = getCollateralValueInDebtAsset(cc.assetType, sd.collateralAsset, sd.collateralAmount);
    totalColValue = totalColValue.percentMul(cc.collateralFactor);

    (, uint256 totalYieldValue) = _getYieldInDebtAsset(sd);
    uint256 totalDebtValue = _getDebtInDebtAsset(sd);

    return (totalColValue + totalYieldValue).wadDiv(totalDebtValue);
  }
}