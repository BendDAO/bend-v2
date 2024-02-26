// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;
import {IPriceOracleGetter} from "../../interfaces/IPriceOracleGetter.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IWETH} from "../../interfaces/IWETH.sol";

library ETHPriceOracle {
    using Math for uint256;

    function getPriceInEth(IPriceOracleGetter _oracle, IWETH _wEth, address _asset) internal view returns (uint256) {
        uint256 price = _oracle.getAssetPrice(_asset);
        uint256 wEthPrice = _oracle.getAssetPrice(address(_wEth));
        return price.mulDiv(10 ** _wEth.decimals(), wEthPrice);
    }
}
