// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTest.t.sol";


contract SimStableTest is BaseTest {
    /**
     * @notice Tests the initial setup of the SimStable contract, ensuring that all constructor parameters
     *         and initial state variables are correctly set.
     */
    function test_initialVariables() public view {
        assertEq(simStable.name(), "SimStable", "Incorrect token name");
        assertEq(simStable.symbol(), "SIM", "Incorrect token symbol");
        assertEq(simStable.totalSupply(), 0, "Incorrect initial balance");

        assertEq(address(simStable.simGov()), address(simGov), "SimGov address not set correctly");
        assertEq(address(simStable.vault()), address(vault), "Vault address not set correctly");

        assertEq(simStable.collateralRatio(), SCALING_FACTOR, "Initial collateral ratio should be SCALING_FACTOR");
        assertEq(simStable.targetCollateralRatio(), targetCollateralRatio, "Incorrect target collateral ratio");
        assertEq(simStable.reCollateralizeTargetRatio(), reCollateralizeTargetRatio, "Incorrect re-collateralize target ratio");
        assertEq(simStable.minCollateralRatio(), minCollateralRatio, "Incorrect minimum collateral ratio");
        assertEq(simStable.maxCollateralRatio(), SCALING_FACTOR, "Maximum collateral ratio should be SCALING_FACTOR");
        assertEq(simStable.collateralRatioAdjustmentCooldown(), collateralRatioAdjustmentCooldown, "Incorrect cooldown duration");
        assertEq(simStable.lastCollateralRatioAdjustment(), block.timestamp, "Incorrect initial collateral ratio adjustment timestamp");

        assertEq(simStable.adjustmentCoefficient(), initialAdjustmentCoefficient, "Incorrect adjustment coefficient");

        assertEq(simStable.collateralToken(), WETH_ADDRESS, "Incorrect collateral token address");
        assertEq(simStable.collateralTokenPair(), DAI_ADDRESS, "Incorrect collateral token pair address");

        assertEq(simStable.UNISWAP_FACTORY(), UNISWAP_FACTORY, "Incorrect Uniswap factory address");
        assertEq(simStable.WETH_ADDRESS(), WETH_ADDRESS, "Incorrect WETH address");

        bytes32 DEFAULT_ADMIN_ROLE = simStable.DEFAULT_ADMIN_ROLE();
        assertTrue(simStable.hasRole(DEFAULT_ADMIN_ROLE, admin), "Admin does not have DEFAULT_ADMIN_ROLE");
        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        assertTrue(simStable.hasRole(ADMIN_ROLE, admin), "Admin does not have ADMIN_ROLE");

    }


    /**
     * @notice Tests the minting process of SimStable.
     */
    function test_mintSimStable_100collateral() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);

        uint256 collateralAmount = 10 ether;
        uint256 userSimStableBalanceBefore = simStable.balanceOf(user);
        uint256 userSimGovBalanceBefore = simGov.balanceOf(user);
        uint256 minSimStableAmount = 10 * weth_price;

        // User minting SimStable
        vm.startPrank(user);
        simStable.mint(collateralAmount, minSimStableAmount);
        vm.stopPrank();

        // assetions
        assertEq(simStable.collateralRatio(), SCALING_FACTOR);

        // Check SimStable balance
        uint256 simStableBalance = simStable.balanceOf(user);
        assertEq(userSimStableBalanceBefore, 0);
        assertEq(simStableBalance, minSimStableAmount);

        // Check SimGov balance after burning
        uint256 userSimGovBalanceAfter = simGov.balanceOf(user);
        assertEq(userSimGovBalanceBefore, 0);
        assertEq(userSimGovBalanceAfter, 0);
    }

    function test_mintSimStable_50collateral() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);
        setCollateralRatio(500_000);

        uint256 collateralAmount = 10 ether;
        mintSimGov(user, 10 * weth_price);
        uint256 userSimStableBalanceBefore = simStable.balanceOf(user);
        uint256 userSimGovBalanceBefore = simGov.balanceOf(user);
        uint256 minSimStableAmount = 20 * weth_price;

        // User minting SimStable
        vm.startPrank(user);
        simStable.mint(collateralAmount, minSimStableAmount);
        vm.stopPrank();

        // assetions
        assertEq(simStable.collateralRatio(), 500_000);

        // Check SimStable balance
        uint256 simStableBalance = simStable.balanceOf(user);
        assertEq(userSimStableBalanceBefore, 0);
        assertEq(simStableBalance, minSimStableAmount);

        // Check SimGov balance after burning
        uint256 userSimGovBalanceAfter = simGov.balanceOf(user);
        assertEq(userSimGovBalanceBefore, 10 * weth_price);
        assertEq(userSimGovBalanceAfter, 0);
    }













}
