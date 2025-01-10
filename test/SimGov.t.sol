// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTest.t.sol";


contract SimGovTest is BaseTest {
    /**
     * @notice Tests the initial setup of the SimGov contract, ensuring that all constructor parameters
     *         and initial state variables are correctly set.
     */
    function test_initialVariables() public view {
        assertEq(simGov.name(), "SimGov", "Incorrect token name");
        assertEq(simGov.symbol(), "SIMGOV", "Incorrect token symbol");
        assertEq(simGov.totalSupply(), 0, "Incorrect initial balance");

        bytes32 DEFAULT_ADMIN_ROLE_SIMGOV = simGov.DEFAULT_ADMIN_ROLE();
        assertTrue(simGov.hasRole(DEFAULT_ADMIN_ROLE_SIMGOV, admin), "Admin does not have DEFAULT_ADMIN_ROLE");
        bytes32 MINTER_ROLE = keccak256("MINTER_ROLE");
        assertTrue(simGov.hasRole(MINTER_ROLE, address(simStable)), "SimStable does not have MINTER_ROLE");

        assertEq(vault.getCollateralBalance(WETH_ADDRESS), 0);
    }

    /**
     * @notice Tests functions access controls.
     */
    function testAdminFunctions() public {
        bytes4 err = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));

        vm.startPrank(user);

        vm.expectPartialRevert(err);
        simGov.mint(address(0x111), 1000);

        vm.expectPartialRevert(err);
        simGov.burn(address(0x111), 1000);

        vm.stopPrank();
    }


}
