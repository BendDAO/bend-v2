// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPriceOracle} from 'src/interfaces/IPriceOracle.sol';

import {Errors} from 'src/libraries/helpers/Errors.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';
import {PriceOracle} from 'src/PriceOracle.sol';

import 'test/mocks/MockERC20.sol';
import 'test/mocks/MockERC721.sol';
import 'test/mocks/MockChainlinkAggregator.sol';

import 'test/setup/TestWithSetup.sol';
import '@forge-std/Test.sol';

contract TestPriceOracle is TestWithSetup {
  MockERC20 mockErc20NotUsed;
  MockERC20 mockErc20;
  MockChainlinkAggregator mockCLAgg;
  MockERC721 mockErc721;
  MockBendNFTOracle mockNftOracle;
  MockERC20 mockErc20InTO;
  MockBendNFTOracle mockTokenOracle;

  address[] mockAssetAddrs;
  address[] mockClAggAddrs;

  address[] sourceAssetAddrs;
  uint8[] sourceTypes;

  function onSetUp() public virtual override {
    super.onSetUp();

    mockErc20NotUsed = new MockERC20('NOUSE', 'NOUSE', 18);
    mockErc20 = new MockERC20('TEST', 'TEST', 18);
    mockCLAgg = new MockChainlinkAggregator(8, 'ETH / USD');

    mockErc721 = new MockERC721('TNFT', 'TNFT');
    mockNftOracle = new MockBendNFTOracle(18);

    mockErc20InTO = new MockERC20('TITO', 'TITO', 18);
    mockTokenOracle = new MockBendNFTOracle(8);

    mockAssetAddrs = new address[](1);
    mockAssetAddrs[0] = address(mockErc20);

    mockClAggAddrs = new address[](1);
    mockClAggAddrs[0] = address(mockCLAgg);

    sourceAssetAddrs = new address[](2);
    sourceAssetAddrs[0] = address(mockErc721);
    sourceAssetAddrs[1] = address(mockErc20InTO);

    sourceTypes = new uint8[](2);
    sourceTypes[0] = Constants.ORACLE_TYPE_BEND_NFT;
    sourceTypes[1] = Constants.ORACLE_TYPE_BEND_TOKEN;
  }

  function test_RevertIf_CallerNotAdmin() public {
    tsHEVM.expectRevert(bytes(Errors.CALLER_NOT_ORACLE_ADMIN));
    tsHEVM.prank(address(tsHacker1));
    tsPriceOracle.setAssetChainlinkAggregators(mockAssetAddrs, mockClAggAddrs);

    tsHEVM.expectRevert(bytes(Errors.CALLER_NOT_ORACLE_ADMIN));
    tsHEVM.prank(address(tsHacker1));
    tsPriceOracle.setAssetOracleSourceTypes(sourceAssetAddrs, sourceTypes);

    tsHEVM.expectRevert(bytes(Errors.CALLER_NOT_ORACLE_ADMIN));
    tsHEVM.prank(address(tsHacker1));
    tsPriceOracle.setBendNFTOracle(address(mockNftOracle));

    tsHEVM.expectRevert(bytes(Errors.CALLER_NOT_ORACLE_ADMIN));
    tsHEVM.prank(address(tsHacker1));
    tsPriceOracle.setBendTokenOracle(address(mockTokenOracle));
  }

  function test_Should_SetAggregators() public {
    tsHEVM.prank(tsOracleAdmin);
    tsPriceOracle.setAssetChainlinkAggregators(mockAssetAddrs, mockClAggAddrs);

    address[] memory retAggs = tsPriceOracle.getAssetChainlinkAggregators(mockAssetAddrs);
    assertEq(retAggs.length, mockAssetAddrs.length, 'retAggs length not match');
    assertEq(retAggs[0], mockClAggAddrs[0], 'retAggs address not match');
  }

  function test_Should_SetSourceTypes() public {
    tsHEVM.prank(tsOracleAdmin);
    tsPriceOracle.setAssetOracleSourceTypes(sourceAssetAddrs, sourceTypes);

    uint8[] memory retTypes = tsPriceOracle.getAssetOracleSourceTypes(sourceAssetAddrs);
    assertEq(retTypes.length, sourceAssetAddrs.length, 'retTypes length not match');
    assertEq(retTypes[0], sourceTypes[0], 'retTypes address not match');
  }

  function test_Should_SetNftOracle() public {
    tsHEVM.prank(tsOracleAdmin);
    tsPriceOracle.setBendNFTOracle(address(mockNftOracle));

    address retNftOracle = tsPriceOracle.getBendNFTOracle();
    assertEq(retNftOracle, address(mockNftOracle), 'retNftOracle address not match');
  }

  function test_Should_SetTokenOracle() public {
    tsHEVM.prank(tsOracleAdmin);
    tsPriceOracle.setBendTokenOracle(address(mockTokenOracle));

    address retTokenOracle = tsPriceOracle.getBendTokenOracle();
    assertEq(retTokenOracle, address(mockTokenOracle), 'retTokenOracle address not match');
  }

  function test_Should_GetAssetPriceFromChainlink() public {
    IPriceOracle oracle = IPriceOracle(tsPriceOracle);

    tsHEVM.prank(tsOracleAdmin);
    tsPriceOracle.setAssetChainlinkAggregators(mockAssetAddrs, mockClAggAddrs);

    uint256 retPrice0 = tsPriceOracle.getAssetPrice(oracle.BASE_CURRENCY());
    assertEq(retPrice0, oracle.BASE_CURRENCY_UNIT(), 'retPrice0 not match');

    mockCLAgg.updateAnswer(1234);
    uint256 retPrice2 = tsPriceOracle.getAssetPriceFromChainlink(address(mockErc20));
    assertEq(retPrice2, 1234, 'retPrice2 not match');

    mockCLAgg.updateAnswer(4321);
    uint256 retPrice3 = tsPriceOracle.getAssetPriceFromChainlink(address(mockErc20));
    assertEq(retPrice3, 4321, 'retPrice3 not match');
  }

  function test_Should_getAssetPriceFromBendNFTOracle() public {
    IPriceOracle oracle = IPriceOracle(tsPriceOracle);

    tsHEVM.prank(tsOracleAdmin);
    tsPriceOracle.setBendNFTOracle(address(mockNftOracle));

    uint256 nftBaseCurrencyInBase = tsPriceOracle.getAssetPrice(oracle.NFT_BASE_CURRENCY());

    mockNftOracle.setAssetPrice(address(mockErc721), 1.234 ether);
    uint256 checkPrice2 = (1.234 ether * nftBaseCurrencyInBase) / oracle.NFT_BASE_CURRENCY_UNIT();
    uint256 retPrice2 = tsPriceOracle.getAssetPriceFromBendNFTOracle(address(mockErc721));
    assertEq(retPrice2, checkPrice2, 'retPrice2 not match');

    mockNftOracle.setAssetPrice(address(mockErc721), 4.321 ether);
    uint256 checkPrice3 = (4.321 ether * nftBaseCurrencyInBase) / oracle.NFT_BASE_CURRENCY_UNIT();
    uint256 retPrice3 = tsPriceOracle.getAssetPriceFromBendNFTOracle(address(mockErc721));
    assertEq(retPrice3, checkPrice3, 'retPrice3 not match');
  }

  function test_Should_getAssetPriceFromBendTokenOracle() public {
    tsHEVM.prank(tsOracleAdmin);
    tsPriceOracle.setBendTokenOracle(address(mockTokenOracle));

    mockTokenOracle.setAssetPrice(address(mockErc20InTO), 1234);
    uint256 retPrice2 = tsPriceOracle.getAssetPriceFromBendTokenOracle(address(mockErc20InTO));
    assertEq(retPrice2, 1234, 'retPrice2 not match');

    mockTokenOracle.setAssetPrice(address(mockErc20InTO), 4321);
    uint256 retPrice3 = tsPriceOracle.getAssetPriceFromBendTokenOracle(address(mockErc20InTO));
    assertEq(retPrice3, 4321, 'retPrice3 not match');
  }

  function test_Should_getAssetPrice() public {
    IPriceOracle oracle = IPriceOracle(tsPriceOracle);

    tsHEVM.startPrank(tsOracleAdmin);

    tsPriceOracle.setBendTokenOracle(address(mockTokenOracle));

    tsPriceOracle.setBendNFTOracle(address(mockNftOracle));

    tsPriceOracle.setAssetChainlinkAggregators(mockAssetAddrs, mockClAggAddrs);

    tsPriceOracle.setAssetOracleSourceTypes(sourceAssetAddrs, sourceTypes);

    tsHEVM.stopPrank();

    mockCLAgg.updateAnswer(1001);
    mockNftOracle.setAssetPrice(address(mockErc721), 2.002 ether);
    mockTokenOracle.setAssetPrice(address(mockErc20InTO), 3003);

    uint256 nftBaseCurrencyInBase = tsPriceOracle.getAssetPrice(oracle.NFT_BASE_CURRENCY());

    uint256 retPrice1 = oracle.getAssetPrice(address(mockErc20));
    assertEq(retPrice1, 1001, 'retPrice1 not match');

    uint256 retPrice2 = oracle.getAssetPrice(address(mockErc721));
    uint256 checkPrice2 = (2.002 ether * nftBaseCurrencyInBase) / oracle.NFT_BASE_CURRENCY_UNIT();
    assertEq(retPrice2, checkPrice2, 'retPrice2 not match');

    uint256 retPrice3 = oracle.getAssetPrice(address(mockErc20InTO));
    assertEq(retPrice3, 3003, 'retPrice3 not match');
  }

  function test_RevertIf_getAssetPrice_NotExist() public {
    tsHEVM.expectRevert(bytes(Errors.ASSET_ORACLE_NOT_EXIST));
    tsPriceOracle.getAssetPrice(address(mockErc20NotUsed));
  }
}
