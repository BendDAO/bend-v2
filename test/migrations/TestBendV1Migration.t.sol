// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'src/interfaces/IWETH.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import 'src/libraries/helpers/Constants.sol';
import 'src/libraries/helpers/Errors.sol';

import 'src/migrations/BendV1Migration.sol';

import 'test/mocks/MockBendV1AddressesProvider.sol';
import 'test/mocks/MockBendV1LendPool.sol';
import 'test/mocks/MockBendV1LendPoolLoan.sol';
import 'test/mocks/MockBendV1ProtocolDataProvider.sol';

import 'test/setup/TestWithPrepare.sol';
import '@forge-std/Test.sol';

contract TestBendV1Migration is TestWithPrepare {
  MockBendV1AddressesProvider internal v1AddressProvider;
  MockBendV1LendPool internal v1LendPool;
  MockBendV1LendPoolLoan internal v1PoolLoan;
  MockBendV1ProtocolDataProvider internal v1DataProvider;

  BendV1Migration internal v1Migration;

  function onSetUp() public virtual override {
    super.onSetUp();

    initCommonPools();

    tsHEVM.startPrank(tsPoolAdmin);
    tsConfigurator.setAssetFlashLoan(tsCommonPoolId, address(tsWETH), true);
    tsConfigurator.setAssetFlashLoan(tsCommonPoolId, address(tsUSDT), true);
    tsHEVM.stopPrank();

    // mock v1 contracts
    v1AddressProvider = new MockBendV1AddressesProvider();
    v1LendPool = new MockBendV1LendPool(address(v1AddressProvider));
    v1PoolLoan = new MockBendV1LendPoolLoan();
    v1DataProvider = new MockBendV1ProtocolDataProvider(address(v1AddressProvider));

    v1AddressProvider.setLendPool(address(v1LendPool));
    v1AddressProvider.setLendPoolLoan(address(v1PoolLoan));
    v1AddressProvider.setBendDataProvider(address(v1DataProvider));

    v1LendPool.initReserve(address(tsWETH));
    v1LendPool.initReserve(address(tsUSDT));

    // v1 migration
    BendV1Migration v1MigrationImpl = new BendV1Migration();
    TransparentUpgradeableProxy v1MigrationProxy = new TransparentUpgradeableProxy(
      address(v1MigrationImpl),
      address(tsProxyAdmin),
      abi.encodeWithSelector(
        v1MigrationImpl.initialize.selector,
        address(tsAddressProvider),
        address(v1AddressProvider)
      )
    );
    v1Migration = BendV1Migration((address(v1MigrationProxy)));
  }

  function test_Should_MigrateDeposit() public {
    tsHEVM.startPrank(address(tsDepositor1));

    // prepare v1 deposit
    tsWETH.approve(address(v1LendPool), type(uint256).max);
    uint256 amount = 123 ether;
    v1LendPool.deposit(address(tsWETH), amount, address(tsDepositor1), 0);

    // approve btoken to v2
    (address bToken, ) = v1LendPool.getReserveToken(address(tsWETH));
    IERC20(bToken).approve(address(v1Migration), type(uint256).max);

    // do the migrate
    v1Migration.migrateDeposit(tsCommonPoolId, address(tsWETH), amount);

    tsHEVM.stopPrank();
  }

  function test_Should_MigrateBorrow_Cross() public {
    // prepare some deposit in v2 & v1
    prepareWETH(tsDepositor1);

    // prepare v1 deposit
    tsHEVM.startPrank(address(tsDepositor2));

    tsWETH.approve(address(v1LendPool), type(uint256).max);
    uint256 depositAmount = 100 ether;
    v1LendPool.deposit(address(tsWETH), depositAmount, address(tsDepositor1), 0);

    tsHEVM.stopPrank();

    // do the real borrow & migrate

    tsHEVM.startPrank(address(tsBorrower1));

    // prepare v1 borrow
    uint256[] memory userTokenIds = tsBorrower1.getTokenIds();
    tsBorrower1.setApprovalForAllERC721(address(tsBAYC), address(v1LendPool), true);
    uint256 borrowAmount = 0.123 ether;
    v1LendPool.borrow(address(tsWETH), borrowAmount, address(tsBAYC), userTokenIds[0], address(tsBorrower1), 0);

    // approve nft & auth to v1 migrate
    tsBorrower1.setApprovalForAllERC721(address(tsBAYC), address(v1Migration), true);
    tsBorrower1.setAuthorization(tsCommonPoolId, address(tsWETH), address(v1Migration), true);

    address[] memory migNftAssets = new address[](1);
    migNftAssets[0] = address(tsBAYC);
    uint256[] memory migTokenIds = new uint256[](1);
    migTokenIds[0] = userTokenIds[0];
    v1Migration.migrateBorrow(tsCommonPoolId, address(tsWETH), migNftAssets, migTokenIds, Constants.SUPPLY_MODE_CROSS);

    tsHEVM.stopPrank();
  }

  function test_Should_MigrateBorrow_Isolate() public {
    // prepare some deposit in v2 & v1
    prepareUSDT(tsDepositor1);

    // prepare v1 deposit
    tsHEVM.startPrank(address(tsDepositor2));

    tsUSDT.approve(address(v1LendPool), type(uint256).max);
    uint256 depositAmount = 100_000 * (10 ** IERC20Metadata(tsUSDT).decimals());
    v1LendPool.deposit(address(tsUSDT), depositAmount, address(tsDepositor1), 0);

    tsHEVM.stopPrank();

    // do the real borrow & migrate

    tsHEVM.startPrank(address(tsBorrower1));

    // prepare v1 borrow
    uint256[] memory userTokenIds = tsBorrower1.getTokenIds();
    tsBorrower1.setApprovalForAllERC721(address(tsBAYC), address(v1LendPool), true);
    uint256 borrowAmount = 1234 * (10 ** IERC20Metadata(tsUSDT).decimals());
    v1LendPool.borrow(address(tsUSDT), borrowAmount, address(tsBAYC), userTokenIds[0], address(tsBorrower1), 0);

    // approve nft & auth to v1 migrate
    tsBorrower1.setApprovalForAllERC721(address(tsBAYC), address(v1Migration), true);
    tsBorrower1.setAuthorization(tsCommonPoolId, address(tsUSDT), address(v1Migration), true);

    address[] memory migNftAssets = new address[](1);
    migNftAssets[0] = address(tsBAYC);
    uint256[] memory migTokenIds = new uint256[](1);
    migTokenIds[0] = userTokenIds[0];
    v1Migration.migrateBorrow(
      tsCommonPoolId,
      address(tsUSDT),
      migNftAssets,
      migTokenIds,
      Constants.SUPPLY_MODE_ISOLATE
    );

    tsHEVM.stopPrank();
  }
}
