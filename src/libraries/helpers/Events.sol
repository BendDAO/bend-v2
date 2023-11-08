// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

library Events {
  event AssetInterestSupplyDataUpdated(address indexed asset, uint256 supplyRate, uint256 supplyIndex);
  event AssetInterestBorrowDataUpdated(address indexed asset, uint256 groupId, uint256 borrowRate, uint256 borrowIndex);

  event DepositERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event WithdrawERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  event DepositERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);
  event WithdrawERC721(address indexed sender, uint256 indexed poolId, address indexed asset, uint256[] tokenIds);

  event BorrowERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);
  event RepayERC20(address indexed sender, uint256 indexed poolId, address indexed asset, uint256 amount);

  event LiquidateERC20(
    address liquidator,
    address indexed user,
    address indexed collateralAsset,
    address indexed debtAsset,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    bool supplyAsCollateral
  );

  event LiquidateERC721(
    address liquidator,
    address indexed user,
    address indexed collateralAsset,
    uint256[] liquidatedCollateralTokenIds,
    bool supplyAsCollateral
  );
}
