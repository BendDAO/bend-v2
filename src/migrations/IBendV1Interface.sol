// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Interfaces for V1 Protcols

interface ILendPoolAddressesProviderV1 {
  function getLendPool() external view returns (address);

  function getLendPoolLoan() external view returns (address);

  function getBendDataProvider() external view returns (address);
}

interface ILendPoolV1 {
  function withdraw(address reserve, uint256 amount, address to) external returns (uint256);

  function repay(address nftAsset, uint256 nftTokenId, uint256 amount) external returns (uint256, bool);

  function getNftDebtData(
    address nftAsset,
    uint256 nftTokenId
  )
    external
    view
    returns (
      uint256 loanId,
      address reserveAsset,
      uint256 totalCollateral,
      uint256 totalDebt,
      uint256 availableBorrows,
      uint256 healthFactor
    );

  function getNftAuctionData(
    address nftAsset,
    uint256 nftTokenId
  )
    external
    view
    returns (uint256 loanId, address bidderAddress, uint256 bidPrice, uint256 bidBorrowAmount, uint256 bidFine);
}

interface ILendPoolLoanV1 {
  function borrowerOf(uint256 loanId) external view returns (address);
}

interface IBendProtocolDataProviderV1 {
  struct ReserveTokenData {
    string tokenSymbol;
    address tokenAddress;
    string bTokenSymbol;
    address bTokenAddress;
    string debtTokenSymbol;
    address debtTokenAddress;
  }

  function getReserveTokenData(address asset) external view returns (ReserveTokenData memory);
}
