// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {ILendPoolAddressesProviderV1, ILendPoolV1} from 'src/migrations/IBendV1Interface.sol';

import './MockBendV1Types.sol';
import './MockBendV1LendPoolLoan.sol';

contract MockBendV1BaseToken is ERC20 {
  uint8 private _decimals;

  constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
    _decimals = decimals_;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public {
    _burn(from, amount);
  }
}

contract MockBToken is MockBendV1BaseToken {
  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) MockBendV1BaseToken(name_, symbol_, decimals_) {}
}

contract MockDebtToken is MockBendV1BaseToken {
  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) MockBendV1BaseToken(name_, symbol_, decimals_) {}
}

contract MockBendV1LendPool is ILendPoolV1 {
  ILendPoolAddressesProviderV1 public addressesProvider;
  mapping(address => MockBendV1Types.ReserveData) internal _reserveDataMap;

  constructor(address provider_) {
    addressesProvider = ILendPoolAddressesProviderV1(provider_);
  }

  function initReserve(address underlyingAsset_) public {
    IERC20Metadata underlyingToken_ = IERC20Metadata(underlyingAsset_);

    MockBToken bToken = new MockBToken(underlyingToken_.name(), underlyingToken_.symbol(), underlyingToken_.decimals());
    MockDebtToken debToken = new MockDebtToken(
      underlyingToken_.name(),
      underlyingToken_.symbol(),
      underlyingToken_.decimals()
    );

    MockBendV1Types.ReserveData storage reserveData = _reserveDataMap[underlyingAsset_];
    reserveData.underlyingAsset = underlyingAsset_;
    reserveData.bTokenAddress = address(bToken);
    reserveData.debtTokenAddress = address(debToken);
  }

  function getReserveData(address underlyingAsset_) public view returns (MockBendV1Types.ReserveData memory) {
    return _reserveDataMap[underlyingAsset_];
  }

  function getReserveToken(address underlyingAsset_) public view returns (address, address) {
    MockBendV1Types.ReserveData storage reserveData = _reserveDataMap[underlyingAsset_];
    return (reserveData.bTokenAddress, reserveData.debtTokenAddress);
  }

  function deposit(address reserve, uint256 amount, address onBehalfOf, uint16 /*referralCode*/) public {
    MockBendV1Types.ReserveData storage reserveData = _reserveDataMap[reserve];

    IERC20(reserve).transferFrom(msg.sender, address(this), amount);

    MockBToken(reserveData.bTokenAddress).mint(onBehalfOf, amount);
  }

  function withdraw(address reserve, uint256 amount, address to) public returns (uint256) {
    MockBendV1Types.ReserveData storage reserveData = _reserveDataMap[reserve];

    MockBToken(reserveData.bTokenAddress).burn(msg.sender, amount);

    IERC20(reserve).transfer(to, amount);

    return amount;
  }

  function borrow(
    address reserveAsset,
    uint256 amount,
    address nftAsset,
    uint256 nftTokenId,
    address onBehalfOf,
    uint16 /*referralCode*/
  ) external {
    MockBendV1LendPoolLoan lendPoolLoan = MockBendV1LendPoolLoan(
      ILendPoolAddressesProviderV1(addressesProvider).getLendPoolLoan()
    );
    lendPoolLoan.setLoanData(nftAsset, nftTokenId, onBehalfOf, reserveAsset, amount);

    IERC721(nftAsset).transferFrom(msg.sender, address(this), nftTokenId);
    IERC20(reserveAsset).transfer(msg.sender, amount);
  }

  function repay(address nftAsset, uint256 nftTokenId, uint256 amount) external returns (uint256, bool) {
    MockBendV1LendPoolLoan lendPoolLoan = MockBendV1LendPoolLoan(
      ILendPoolAddressesProviderV1(addressesProvider).getLendPoolLoan()
    );

    uint256 loanId = lendPoolLoan.getCollateralLoanId(nftAsset, nftTokenId);

    (address borrower, address reserveAsset, uint256 totalDebt, uint256 bidFineInLoan) = lendPoolLoan.getLoanData(
      loanId
    );
    require(bidFineInLoan == 0, 'loan is in auction');

    if (amount > totalDebt) {
      amount = totalDebt;
    }
    totalDebt -= amount;
    lendPoolLoan.setTotalDebt(loanId, totalDebt);

    IERC20(reserveAsset).transferFrom(msg.sender, address(this), amount);

    if (totalDebt == 0) {
      IERC721(nftAsset).transferFrom(address(this), borrower, nftTokenId);
    }

    return (amount, true);
  }

  function redeem(address nftAsset, uint256 nftTokenId, uint256 amount, uint256 bidFine) external returns (uint256) {
    MockBendV1LendPoolLoan lendPoolLoan = MockBendV1LendPoolLoan(
      ILendPoolAddressesProviderV1(addressesProvider).getLendPoolLoan()
    );
    uint256 loanId = lendPoolLoan.getCollateralLoanId(nftAsset, nftTokenId);

    (, address reserveAsset, uint256 totalDebt, uint256 bidFineInLoan) = lendPoolLoan.getLoanData(loanId);
    uint256 maxRedeemAmount = (totalDebt * 9) / 10;
    require(amount <= maxRedeemAmount, 'exceed max redeem amount');
    require(bidFine == bidFineInLoan, 'insufficient bid fine');

    IERC20(reserveAsset).transferFrom(msg.sender, address(this), (amount + bidFine));

    totalDebt -= amount;
    lendPoolLoan.setTotalDebt(loanId, totalDebt);
    lendPoolLoan.setBidFine(loanId, 0);

    return amount;
  }

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
    )
  {
    MockBendV1LendPoolLoan lendPoolLoan = MockBendV1LendPoolLoan(
      ILendPoolAddressesProviderV1(addressesProvider).getLendPoolLoan()
    );

    loanId = lendPoolLoan.getCollateralLoanId(nftAsset, nftTokenId);
    (, reserveAsset, totalDebt, ) = lendPoolLoan.getLoanData(loanId);

    totalCollateral = totalDebt;
    availableBorrows = 0;
    healthFactor = 1e18;
  }

  function getNftAuctionData(
    address nftAsset,
    uint256 nftTokenId
  )
    external
    view
    returns (uint256 loanId, address bidderAddress, uint256 bidPrice, uint256 bidBorrowAmount, uint256 bidFine)
  {
    MockBendV1LendPoolLoan lendPoolLoan = MockBendV1LendPoolLoan(
      ILendPoolAddressesProviderV1(addressesProvider).getLendPoolLoan()
    );

    loanId = lendPoolLoan.getCollateralLoanId(nftAsset, nftTokenId);

    (, , bidBorrowAmount, bidFine) = lendPoolLoan.getLoanData(loanId);

    bidderAddress = msg.sender;
    bidPrice = (bidBorrowAmount * 105) / 100;
  }
}
