// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IACLManager} from './interfaces/IACLManager.sol';
import {Errors} from './libraries/helpers/Errors.sol';

contract PriceOracle is Initializable {
  IACLManager public aclManager;

  address public baseCurrency;
  uint256 public baseCurrencyUnit;

  constructor() {
    _disableInitializers();
  }

  /**
   * @dev initialize
   * @dev The ACL admin should be initialized at the addressesProvider beforehand
   * @param aclManager_ The address of the ACL Manager
   */
  function initialize(address aclManager_, address baseCurrency_, uint256 baseCurrencyUnit_) public initializer {
    require(aclManager_ != address(0), Errors.CE_ACL_MANAGER_CANNOT_BE_ZERO);
    aclManager = IACLManager(aclManager_);

    // if use US Dollars, baseCurrency will be 0 and unit is 1e8
    baseCurrency = baseCurrency_;
    baseCurrencyUnit = baseCurrencyUnit_;
  }
}
