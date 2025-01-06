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
        simStable.mint(WETH_ADDRESS, 1 ether);
        vm.stopPrank();

        assertGt(simStable.balanceOf(user), 3500 * 10 ** 18);
        assertGt(weth.balanceOf(address(vault)), 0);
    }

    function test_redeem() public {
        // vm.startPrank(admin);
        // simStable.setCollateralRatio(750_000);
        // vm.stopPrank();

        vm.startPrank(user);
        simStable.mint(WETH_ADDRESS, 1 ether);
        vm.stopPrank();
        console.log(simStable.totalSupply());

        vm.startPrank(admin);
        simStable.setCollateralRatio(750_000);
        // simStable.setCollateralRatio(1_000_000);
        vm.stopPrank();

        
        vm.startPrank(user);
        simStable.redeem(WETH_ADDRESS, simStable.balanceOf(user) / 2);
        vm.stopPrank();
        console.log(simStable.totalSupply());

        vm.startPrank(user);
        simStable.redeem(WETH_ADDRESS, simStable.balanceOf(user));
        vm.stopPrank();
        console.log(simStable.totalSupply());
    }



}
