// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'src/libraries/helpers/Constants.sol';

import '../helpers/TestData.sol';

import './IntegrationTest.sol';

contract TestIntegrationDeposit is IntegrationTest {
  function onSetUp() public virtual override {
    super.onSetUp();
  }

  function testShouldDepositERC20() public {
    uint256 amount = 100 ether;

    tsDepositor1.approveERC20(address(tsWETH), amount);
    tsDepositor1.depositERC20(tsCommonPoolId, address(tsWETH), amount);

    TestData.AssetData memory testAssetData = tsDataHelper.getAssetData(tsCommonPoolId, address(tsWETH), 0);
    assertEq(testAssetData.totalCrossSupplied, amount, 'totalCrossSupplied not match');
    assertEq(testAssetData.totalIsolateSupplied, 0, 'totalIsolateSupplied not match');
    assertEq(testAssetData.availableSupply, amount, 'totalIsolateSupplied not match');

    TestData.UserAssetData memory testUserData = tsDataHelper.getUserAssetData(
      tsCommonPoolId,
      address(tsWETH),
      Constants.ASSET_TYPE_ERC20,
      0,
      address(tsDepositor1)
    );
    assertGt(testUserData.scaledSupplyBlance, 0, 'scaledSupplyBlance not match');
    assertEq(testUserData.supplyBlance, amount, 'supplyBlance not match');
  }

  function testShouldDepositERC721() public {
    uint256[] memory tokenIds = tsDepositor1.getTokenIds();
    uint256 amount = tokenIds.length;

    tsDepositor1.setApprovalForAllERC721(address(tsBAYC));
    tsDepositor1.depositERC721(tsCommonPoolId, address(tsBAYC), tokenIds, Constants.SUPPLY_MODE_CROSS);

    TestData.AssetData memory testAssetData = tsDataHelper.getAssetData(tsCommonPoolId, address(tsBAYC), 0);
    assertEq(testAssetData.totalCrossSupplied, amount, 'totalCrossSupplied not match');
    assertEq(testAssetData.totalIsolateSupplied, 0, 'totalIsolateSupplied not match');
    assertEq(testAssetData.availableSupply, amount, 'totalIsolateSupplied not match');

    TestData.UserAssetData memory testUserData = tsDataHelper.getUserAssetData(
      tsCommonPoolId,
      address(tsBAYC),
      Constants.ASSET_TYPE_ERC721,
      Constants.SUPPLY_MODE_CROSS,
      address(tsDepositor1)
    );
    assertEq(testUserData.supplyBlance, amount, 'supplyBlance not match');
  }
}
