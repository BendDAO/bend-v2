// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Module interfaces fro V2 Protocols

interface IBVaultV2 {
  function depositERC20(uint32 poolId, address asset, uint256 amount, address onBehalf) external;

  function depositERC721(
    uint32 poolId,
    address asset,
    uint256[] calldata tokenIds,
    uint8 supplyMode,
    address onBehalf
  ) external;
}

interface ICrossLendingV2 {
  function crossBorrowERC20(
    uint32 poolId,
    address asset,
    uint8[] calldata groups,
    uint256[] calldata amounts,
    address onBehalf,
    address receiver
  ) external;
}

interface IIsolateLendingV2 {
  function isolateBorrow(
    uint32 poolId,
    address nftAsset,
    uint256[] calldata nftTokenIds,
    address asset,
    uint256[] calldata amounts,
    address onBehalf,
    address receiver
  ) external;
}

interface IFlashLoanV2 {
  function flashLoanERC20(
    uint32 poolId,
    address[] calldata assets,
    uint256[] calldata amounts,
    address receiverAddress,
    bytes calldata params
  ) external;
}

interface IPoolLensV2 {
  function getAssetLendingConfig(
    uint32 poolId,
    address asset
  )
    external
    view
    returns (
      uint8 classGroup,
      uint16 feeFactor,
      uint16 collateralFactor,
      uint16 liquidationThreshold,
      uint16 liquidationBonus
    );

  function getUserAssetData(
    address user,
    uint32 poolId,
    address asset
  )
    external
    view
    returns (
      uint256 totalCrossSupply,
      uint256 totalIsolateSupply,
      uint256 totalCrossBorrow,
      uint256 totalIsolateBorrow
    );

  function getIsolateCollateralData(
    uint32 poolId,
    address nftAsset,
    uint256 tokenId,
    address debtAsset
  ) external view returns (uint256 totalCollateral, uint256 totalBorrow, uint256 availableBorrow, uint256 healthFactor);
}
