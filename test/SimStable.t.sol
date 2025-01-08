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
        simStable.mint(1 ether, 0);
        vm.stopPrank();

        // assertGt(simStable.balanceOf(user), 3500 * 10 ** 18);
        // assertGt(weth.balanceOf(address(vault)), 0);
    }

    function test_redeem() public {
        vm.startPrank(admin);
        // simStable.setCollateralRatio(750_000);
        // simStable.setCollateralRatio(500_000);
        vm.stopPrank();

        vm.startPrank(user);
        simStable.mint(1 ether, 0);
        vm.stopPrank();
        console.log(simStable.totalSupply());

        vm.startPrank(admin);
        simStable.setCollateralRatio(500_000);
        // simStable.setCollateralRatio(1_000_000);
        vm.stopPrank();


        // vm.startPrank(user);
        // simStable.redeem(simStable.balanceOf(user) / 2);
        // vm.stopPrank();
        // console.log(simStable.totalSupply());

        vm.startPrank(user);
        simStable.redeem(simStable.balanceOf(user), 0, 0);
        vm.stopPrank();
        console.log(simStable.totalSupply());
    }

    function test_get_price() public {
        log_get_price();
    }

    function log_get_price() public view {
        uint simStablePrice = simStable.getTokenPriceSpot(WETH_ADDRESS, address(simStable));
        uint simGovPrice = simStable.getTokenPriceSpot(WETH_ADDRESS, address(simGov));
        console.log("simStablePrice", simStablePrice);
        console.log("simGovPrice   ", simGovPrice);
    }


    function test_add_liquidity() public {
        vm.startPrank(address(admin));
        simStable.addLiquidity(UNISWAP_ROUTERV02, WETH_ADDRESS, address(simStable), 1 ether, 3000 ether, address(0));
        simGov.mint(address(simStable), 30000 ether);
        simStable.addLiquidity(UNISWAP_ROUTERV02, WETH_ADDRESS, address(simGov), 1 ether, 30000 ether, address(0));
        vm.stopPrank();        
    }




    function test_buyback() public {
        vm.startPrank(admin);
        simStable.setCollateralRatio(1_000_000);
        vm.stopPrank();

        vm.startPrank(user);
        simStable.mint(10 ether, 0);
        vm.stopPrank();

        vm.startPrank(admin);
        simStable.setCollateralRatio(500_000);
        vm.stopPrank();

        vm.startPrank(user);
        simStable.buyback(7_000 ether);
        vm.stopPrank();

        vm.startPrank(admin);
        simStable.setCollateralRatio(600_000);
        vm.stopPrank();

        vm.startPrank(user);
        simStable.buyback(400 ether);
        vm.stopPrank();
    }




}
