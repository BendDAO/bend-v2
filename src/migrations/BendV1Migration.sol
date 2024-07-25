// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable2StepUpgradeable} from '@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol';
import {IERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeERC20Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

import {IAddressProvider} from 'src/interfaces/IAddressProvider.sol';
import {IFlashLoanReceiver} from 'src/interfaces/IFlashLoanReceiver.sol';

import {IBVaultV2, ICrossLendingV2, IIsolateLendingV2, IFlashLoanV2, IPoolLensV2} from './IBendV2Interface.sol';
import {ILendPoolAddressesProviderV1, ILendPoolV1, ILendPoolLoanV1, IBendProtocolDataProviderV1} from './IBendV1Interface.sol';

import {Constants} from 'src/libraries/helpers/Constants.sol';

/// @notice Contract allowing to migrate a position from BendDAO V1 to V2 easily.
contract BendV1Migration is Ownable2StepUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IAddressProvider public addressProviderV2;
  address public poolManagerV2;
  IPoolLensV2 public poolLensV2;
  IBVaultV2 public bvaultV2;
  ICrossLendingV2 public crossLendingV2;
  IIsolateLendingV2 public isolateLendingV2;
  IFlashLoanV2 public flashLoanV2;

  ILendPoolAddressesProviderV1 public addressProviderV1;
  ILendPoolV1 public poolV1;
  ILendPoolLoanV1 public poolLoanV1;
  IBendProtocolDataProviderV1 dataProviderV1;

  constructor() {
    _disableInitializers();
  }

  function initialize(address addressProviderV2_, address addressProviderV1_) public initializer {
    __Ownable2Step_init();

    addressProviderV2 = IAddressProvider(addressProviderV2_);
    poolManagerV2 = addressProviderV2.getPoolManager();
    poolLensV2 = IPoolLensV2(addressProviderV2.getPoolModuleProxy(Constants.MODULEID__POOL_LENS));
    bvaultV2 = IBVaultV2(addressProviderV2.getPoolModuleProxy(Constants.MODULEID__BVAULT));
    crossLendingV2 = ICrossLendingV2(addressProviderV2.getPoolModuleProxy(Constants.MODULEID__CROSS_LENDING));
    isolateLendingV2 = IIsolateLendingV2(addressProviderV2.getPoolModuleProxy(Constants.MODULEID__ISOLATE_LENDING));
    flashLoanV2 = IFlashLoanV2(addressProviderV2.getPoolModuleProxy(Constants.MODULEID__FLASHLOAN));

    addressProviderV1 = ILendPoolAddressesProviderV1(addressProviderV1_);
    poolV1 = ILendPoolV1(addressProviderV1.getLendPool());
    poolLoanV1 = ILendPoolLoanV1(addressProviderV1.getLendPoolLoan());
    dataProviderV1 = IBendProtocolDataProviderV1(addressProviderV1.getBendDataProvider());
  }

  /// @notice user need approve asset's bToken to this contract
  function migrateDeposit(uint32 poolId, address asset, uint256 amount) public {
    // step 1:
    IBendProtocolDataProviderV1.ReserveTokenData memory tokenData = dataProviderV1.getReserveTokenData(asset);
    IERC20Upgradeable(tokenData.bTokenAddress).safeTransferFrom(msg.sender, address(this), amount);

    poolV1.withdraw(asset, amount, address(this));

    // step 2:
    IERC20Upgradeable(tokenData.bTokenAddress).safeApprove(poolManagerV2, amount);
    bvaultV2.depositERC20(poolId, asset, amount, msg.sender);
  }

  struct MigrateBorrowLocalVars {
    address borrower;
    uint256 i;
    uint256 bidFine;
    uint256 loanId;
    address debtAsset;
    uint256[] debtAmounts;
    address[] flParamsAssets;
    uint256[] flParamsAmounts;
    bytes flParamsParams;
    address paramsBorrower;
  }

  /// @notice user need approve nft asset to this contract
  function migrateBorrow(
    uint32 poolId,
    address asset,
    address[] calldata nftAssets,
    uint256[] calldata tokenIds,
    uint8 supplyMode
  ) public {
    MigrateBorrowLocalVars memory vars;

    vars.flParamsAssets = new address[](1);
    vars.flParamsAmounts = new uint256[](1);
    vars.borrower = msg.sender;

    for (vars.i = 0; vars.i < tokenIds.length; vars.i++) {
      (, , , , vars.bidFine) = poolV1.getNftAuctionData(nftAssets[vars.i], tokenIds[vars.i]);
      require(vars.bidFine == 0, 'BV1M: nft in auction');

      (vars.loanId, vars.debtAsset, , vars.debtAmounts[vars.i], , ) = poolV1.getNftDebtData(
        nftAssets[vars.i],
        tokenIds[vars.i]
      );

      vars.borrower = poolLoanV1.borrowerOf(vars.loanId);
      if (vars.i == 0) {
        require(vars.debtAsset != asset, 'BV1M: debt asset not same');

        // check borrower must be caller
        require(vars.borrower == msg.sender, 'BV1M: caller not borrower');
        vars.flParamsAssets[0] = vars.debtAsset;
        vars.paramsBorrower = vars.borrower;
      } else {
        // check borrower and asset must be same
        require(vars.flParamsAssets[0] == vars.debtAsset, 'BV1M: old debt asset not same');
        require(vars.paramsBorrower == vars.borrower, 'BV1M: borrower not same');
      }

      // new debt should cover old debt + flash loan premium (optional)
      vars.flParamsAmounts[0] += vars.debtAmounts[vars.i];
    }

    vars.flParamsParams = abi.encode(
      vars.paramsBorrower,
      poolId,
      asset,
      nftAssets,
      tokenIds,
      supplyMode,
      vars.debtAmounts
    );

    flashLoanV2.flashLoanERC20(poolId, vars.flParamsAssets, vars.flParamsAmounts, address(this), vars.flParamsParams);
  }

  struct ExecuteOperationERC20LocalVars {
    uint256 i;
    address borrower;
    uint32 poolId;
    address asset;
    address[] nftAssets;
    uint256[] tokenIds;
    uint8 supplyMode;
    uint256[] debtAmounts;
    // tmp params for v2
    uint256[] v2ParamTokenIds;
    uint8[] v2ParamGroups;
    uint256[] v2ParamAmounts;
    // result checks for v2
    uint256 totalCrossSupplyBefore;
    uint256 totalIsolateSupplyBefore;
    uint256 totalCrossBorrowBefore;
    uint256 totalIsolateBorrowBefore;
    uint256 totalCrossSupplyAfter;
    uint256 totalIsolateSupplyAfter;
    uint256 totalCrossBorrowAfter;
    uint256 totalIsolateBorrowAfter;
  }

  function executeOperationERC20(
    address[] calldata assets,
    uint256[] calldata amounts,
    address initiator,
    address operator,
    bytes calldata params
  ) public returns (bool) {
    ExecuteOperationERC20LocalVars memory execVars;
    execVars.v2ParamTokenIds = new uint256[](1);
    execVars.v2ParamGroups = new uint8[](1);
    execVars.v2ParamAmounts = new uint256[](1);

    require(msg.sender == poolManagerV2, 'BV1M: sender not poolManagerV2');
    require(initiator == address(this), 'BV1M: initiator not address(this)');
    require(operator == poolManagerV2, 'BV1M: operator not poolManagerV2');

    require(assets.length == 1, 'BV1M: multiple assets not supported');
    require(amounts.length == 1, 'BV1M: multiple amounts not supported');

    (
      execVars.borrower,
      execVars.poolId,
      execVars.asset,
      execVars.nftAssets,
      execVars.tokenIds,
      execVars.supplyMode,
      execVars.debtAmounts
    ) = abi.decode(params, (address, uint32, address, address[], uint256[], uint8, uint256[]));

    for (execVars.i = 0; execVars.i < execVars.nftAssets.length; execVars.i++) {
      _doMigrateOneBorrow(execVars);
    }

    IERC20Upgradeable(assets[0]).safeApprove(msg.sender, amounts[0]);

    return true;
  }

  function _doMigrateOneBorrow(ExecuteOperationERC20LocalVars memory execVars) internal {
    execVars.v2ParamTokenIds[0] = execVars.tokenIds[execVars.i];
    execVars.v2ParamAmounts[0] = execVars.debtAmounts[execVars.i];

    // step 1.1: repay debt to v1
    IERC20Upgradeable(execVars.asset).safeApprove(poolManagerV2, execVars.debtAmounts[execVars.i]);
    poolV1.repay(execVars.nftAssets[execVars.i], execVars.tokenIds[execVars.i], execVars.debtAmounts[execVars.i]);

    // step 1.2: transfer nft from borrower's wallet
    IERC721Upgradeable(execVars.nftAssets[execVars.i]).safeTransferFrom(
      execVars.borrower,
      address(this),
      execVars.tokenIds[execVars.i]
    );

    (
      execVars.totalCrossSupplyBefore,
      execVars.totalIsolateSupplyBefore,
      execVars.totalCrossBorrowBefore,
      execVars.totalIsolateBorrowBefore
    ) = poolLensV2.getUserAssetData(execVars.borrower, execVars.poolId, execVars.asset);

    // step 2.1: deposit nft to v2
    bvaultV2.depositERC721(
      execVars.poolId,
      execVars.asset,
      execVars.v2ParamTokenIds,
      execVars.supplyMode,
      execVars.borrower
    );

    // step 2.2: borrow from v2
    if (execVars.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      (execVars.v2ParamGroups[0], , , , ) = poolLensV2.getAssetLendingConfig(execVars.poolId, execVars.asset);

      crossLendingV2.crossBorrowERC20(
        execVars.poolId,
        execVars.asset,
        execVars.v2ParamGroups,
        execVars.v2ParamAmounts,
        execVars.borrower,
        address(this)
      );
    } else if (execVars.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      isolateLendingV2.isolateBorrow(
        execVars.poolId,
        execVars.nftAssets[execVars.i],
        execVars.v2ParamTokenIds,
        execVars.asset,
        execVars.v2ParamAmounts,
        execVars.borrower,
        address(this)
      );
    }

    // Last step: check the results are expected
    (
      execVars.totalCrossSupplyAfter,
      execVars.totalIsolateSupplyAfter,
      execVars.totalCrossBorrowAfter,
      execVars.totalIsolateBorrowAfter
    ) = poolLensV2.getUserAssetData(execVars.borrower, execVars.poolId, execVars.asset);

    if (execVars.supplyMode == Constants.SUPPLY_MODE_CROSS) {
      require(execVars.totalCrossSupplyAfter == (execVars.totalCrossSupplyBefore + 1), 'BV1M: cross supply not match');
      require(
        execVars.totalCrossBorrowAfter == (execVars.totalCrossBorrowBefore + execVars.v2ParamAmounts[0]),
        'BV1M: cross borrow not match'
      );
    } else if (execVars.supplyMode == Constants.SUPPLY_MODE_ISOLATE) {
      require(
        execVars.totalIsolateSupplyAfter == (execVars.totalIsolateSupplyBefore + 1),
        'BV1M: isolate supply not match'
      );
      require(
        execVars.totalIsolateBorrowAfter == (execVars.totalIsolateBorrowBefore + execVars.v2ParamAmounts[0]),
        'BV1M: isolate borrow not match'
      );
    }
  }

  function executeOperationERC721(
    address[] calldata /*nftAssets*/,
    uint256[] calldata /*tokenIds*/,
    address /*initiator*/,
    address /*operator*/,
    bytes calldata /*params*/
  ) public pure returns (bool) {
    return false;
  }
}
