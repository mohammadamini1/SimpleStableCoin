// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTest.t.sol";


contract VaultTest is BaseTest {
    /**
     * @notice Tests the initial setup of the vault contract, ensuring that all constructor parameters
     *         and initial state variables are correctly set.
     */
    function test_initialVariables() public view {
        bytes32 DEFAULT_ADMIN_ROLE_VAULT = vault.DEFAULT_ADMIN_ROLE();
        assertTrue(vault.hasRole(DEFAULT_ADMIN_ROLE_VAULT, admin), "Admin does not have DEFAULT_ADMIN_ROLE");
        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        assertTrue(vault.hasRole(ADMIN_ROLE, admin), "Admin does not have ADMIN_ROLE");
        bytes32 SIMSTABLE_CONTRACT_ROLE = keccak256("SIMSTABLE_CONTRACT_ROLE");
        assertTrue(vault.hasRole(SIMSTABLE_CONTRACT_ROLE, address(simStable)), "SimStable does not have SIMSTABLE_CONTRACT_ROLE");
    }

    /**
     * @notice Tests functions accress controls.
     */
    function testAdminFunctions() public {
        bytes4 err = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));

        vm.startPrank(user);

        vm.expectPartialRevert(err);
        vault.depositCollateral(address(0x111), user, 1000);

        vm.expectPartialRevert(err);
        vault.withdrawCollateral(address(0x111), user, 1000);

        vm.stopPrank();
    }
}
