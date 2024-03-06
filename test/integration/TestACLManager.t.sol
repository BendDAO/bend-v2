// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import 'test/setup/TestWithSetup.sol';
import '@forge-std/Test.sol';

contract TestACLManager is TestWithSetup {
  function test_RevertIf_CallerNotAdmin() public {
    // pool admin
    tsHEVM.expectRevert(
      bytes(
        'AccessControl: account 0xf38932f436956699c415112c97e2d0b24c6632c9 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );
    tsHEVM.prank(address(tsHacker1));
    tsAclManager.addPoolAdmin(address(tsHacker1));

    tsHEVM.expectRevert(
      bytes(
        'AccessControl: account 0xf38932f436956699c415112c97e2d0b24c6632c9 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );
    tsHEVM.prank(address(tsHacker1));
    tsAclManager.removePoolAdmin(address(tsHacker1));

    // emergency admin
    tsHEVM.expectRevert(
      bytes(
        'AccessControl: account 0xf38932f436956699c415112c97e2d0b24c6632c9 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );
    tsHEVM.prank(address(tsHacker1));
    tsAclManager.addEmergencyAdmin(address(tsHacker1));

    tsHEVM.expectRevert(
      bytes(
        'AccessControl: account 0xf38932f436956699c415112c97e2d0b24c6632c9 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );
    tsHEVM.prank(address(tsHacker1));
    tsAclManager.removeEmergencyAdmin(address(tsHacker1));

    // oracle admin
    tsHEVM.expectRevert(
      bytes(
        'AccessControl: account 0xf38932f436956699c415112c97e2d0b24c6632c9 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );
    tsHEVM.prank(address(tsHacker1));
    tsAclManager.addOracleAdmin(address(tsHacker1));

    tsHEVM.expectRevert(
      bytes(
        'AccessControl: account 0xf38932f436956699c415112c97e2d0b24c6632c9 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );
    tsHEVM.prank(address(tsHacker1));
    tsAclManager.removeOracleAdmin(address(tsHacker1));
  }

  function test_Should_PoolAdmin() public {
    address newAdmin = address(tsDepositor1);

    tsHEVM.startPrank(tsAclAdmin);

    tsAclManager.addPoolAdmin(newAdmin);
    assertEq(tsAclManager.isPoolAdmin(newAdmin), true, 'newAdmin should added');

    tsAclManager.removePoolAdmin(newAdmin);
    assertEq(tsAclManager.isPoolAdmin(newAdmin), false, 'newAdmin should removed');

    tsHEVM.stopPrank();
  }

  function test_Should_EmergencyAdmin() public {
    address newAdmin = address(tsDepositor1);

    tsHEVM.startPrank(tsAclAdmin);

    tsAclManager.addEmergencyAdmin(newAdmin);
    assertEq(tsAclManager.isEmergencyAdmin(newAdmin), true, 'newAdmin should added');

    tsAclManager.removeEmergencyAdmin(newAdmin);
    assertEq(tsAclManager.isEmergencyAdmin(newAdmin), false, 'newAdmin should removed');

    tsHEVM.stopPrank();
  }

  function test_Should_OracleAdmin() public {
    address newAdmin = address(tsDepositor1);

    tsHEVM.startPrank(tsAclAdmin);

    tsAclManager.addOracleAdmin(newAdmin);
    assertEq(tsAclManager.isOracleAdmin(newAdmin), true, 'newAdmin should added');

    tsAclManager.removeOracleAdmin(newAdmin);
    assertEq(tsAclManager.isOracleAdmin(newAdmin), false, 'newAdmin should removed');

    tsHEVM.stopPrank();
  }
}
