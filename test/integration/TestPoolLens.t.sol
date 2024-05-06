// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'src/libraries/helpers/Constants.sol';
import 'src/libraries/helpers/Errors.sol';

import 'test/setup/TestWithPrepare.sol';

contract TestPoolLens is TestWithPrepare {
  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();
  }

  struct GetUserAccountDataForSupplyAssetTestVars {
    uint256 totalCollateralInBase;
    uint256 totalBorrowInBase;
    uint256 availableBorrowInBase;
    uint256 avgLtv;
    uint256 avgLiquidationThreshold;
    uint256 healthFactor;
  }

  function test_Should_GetUserAccountDataForSupplyAsset() public {
    tsDepositor1.approveERC20(address(tsWETH), type(uint256).max);

    uint256 amount1 = 100 ether;
    tsDepositor1.depositERC20(tsCommonPoolId, address(tsWETH), amount1);

    GetUserAccountDataForSupplyAssetTestVars memory vars1;
    (
      vars1.totalCollateralInBase,
      vars1.totalBorrowInBase,
      vars1.availableBorrowInBase,
      vars1.avgLtv,
      vars1.avgLiquidationThreshold,
      vars1.healthFactor
    ) = tsPoolLens.getUserAccountDataForSupplyAsset(address(tsDepositor1), tsCommonPoolId, true, address(tsWETH), 0);

    uint256 amount2 = 50 ether;
    GetUserAccountDataForSupplyAssetTestVars memory vars2;
    (
      vars2.totalCollateralInBase,
      vars2.totalBorrowInBase,
      vars2.availableBorrowInBase,
      vars2.avgLtv,
      vars2.avgLiquidationThreshold,
      vars2.healthFactor
    ) = tsPoolLens.getUserAccountDataForSupplyAsset(
      address(tsDepositor1),
      tsCommonPoolId,
      true,
      address(tsWETH),
      amount2
    );

    assertGt(vars2.totalCollateralInBase, vars1.totalCollateralInBase, 'vars2.totalCollateralInBase not gt');
    assertGt(vars2.availableBorrowInBase, vars1.availableBorrowInBase, 'vars2.availableBorrowInBase not gt');
    assertEq(vars2.avgLtv, vars1.avgLtv, 'vars2.avgLtv not eq');
    assertEq(vars2.avgLiquidationThreshold, vars1.avgLiquidationThreshold, 'vars2.avgLiquidationThreshold not eq');

    GetUserAccountDataForSupplyAssetTestVars memory vars3;
    (
      vars3.totalCollateralInBase,
      vars3.totalBorrowInBase,
      vars3.availableBorrowInBase,
      vars3.avgLtv,
      vars3.avgLiquidationThreshold,
      vars3.healthFactor
    ) = tsPoolLens.getUserAccountDataForSupplyAsset(
      address(tsDepositor1),
      tsCommonPoolId,
      false,
      address(tsWETH),
      amount2
    );

    assertLt(vars3.totalCollateralInBase, vars1.totalCollateralInBase, 'vars3.totalCollateralInBase not lt');
    assertLt(vars3.availableBorrowInBase, vars1.availableBorrowInBase, 'vars3.availableBorrowInBase not lt');
    assertEq(vars3.avgLtv, vars1.avgLtv, 'vars3.avgLtv not eq');
    assertEq(vars3.avgLiquidationThreshold, vars1.avgLiquidationThreshold, 'vars3.avgLiquidationThreshold not eq');
  }
}
