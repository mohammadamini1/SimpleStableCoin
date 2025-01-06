// contracts/test/SimStableTest.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTest.t.sol";

/**
 * @title SimStableTest
 * @notice Tests the mint functionality of the SimStable contract.
 */
contract SimStableTest is BaseTest {


    function test_mint() public {
        vm.startPrank(user);
        simStable.mint(WETH_ADDRESS, 1);
        vm.stopPrank();

        assertGt(simStable.balanceOf(user), 3500 * 10 ** 18);
        assertGt(weth.balanceOf(address(vault)), 0);
    }


}
