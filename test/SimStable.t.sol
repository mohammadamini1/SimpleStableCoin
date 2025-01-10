// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseTest.t.sol";


contract SimStableTest is BaseTest {
    error InsufficientCollateral(uint256 required, uint256 surplus);


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

        // Assertions
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


    /**
     * @notice Tests the redeeming process of SimStable.
     */
    function testRedeemSimStable_100collateral() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);

        uint256 collateralAmount = 10 ether;
        uint256 minSimStableAmount = 10 * weth_price;

        // Mint
        vm.startPrank(user);
        simStable.mint(collateralAmount, minSimStableAmount);
        uint256 simStableBalance = simStable.balanceOf(user);
        assertEq(simStableBalance, minSimStableAmount);

        // Redeem
        simStable.redeem(simStableBalance, collateralAmount, 0);
        simStableBalance = simStable.balanceOf(user);
        assertEq(simStableBalance, 0);
        uint256 simStableGov = simGov.balanceOf(user);
        assertEq(simStableGov, 0);
        vm.stopPrank();
    }

    function testRedeemSimStable_50collateral() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);
        setCollateralRatio(500_000);

        uint256 collateralAmount = 10 ether;
        uint256 simGovAmount = 10 * weth_price;
        mintSimGov(user, simGovAmount);
        uint256 minSimStableAmount = 20 * weth_price;
        uint256 wethBalance = weth.balanceOf(user);

        // Mint
        vm.startPrank(user);
        simStable.mint(collateralAmount, minSimStableAmount);
        uint256 simStableBalance = simStable.balanceOf(user);
        assertEq(simStableBalance, minSimStableAmount);
        uint256 simGovBalance = simGov.balanceOf(user);
        assertEq(simGovBalance, 0);

        // Redeem
        simStable.redeem(simStableBalance, collateralAmount, simGovAmount);
        simStableBalance = simStable.balanceOf(user);
        assertEq(simStableBalance, 0);
        uint256 simStableGov = simGov.balanceOf(user);
        assertEq(simStableGov, simGovAmount);
        assertEq(wethBalance, weth.balanceOf(user));
        vm.stopPrank();
    }


    /**
     * @notice Tests buying back SimGov when collateral ratio exceeds target.
     */
    function testBuybackSimGov() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);

        uint256 collateralAmount = 99 ether;
        uint256 minSimStableAmount = 99 * weth_price;
        uint256 simGovAmount = 9 * weth_price; // 10%
        mintSimGov(user, simGovAmount);
        uint256 wethBalance = weth.balanceOf(user);

        // Mint
        vm.startPrank(user);
        simStable.mint(collateralAmount, minSimStableAmount);
        vm.stopPrank();

        setCollateralRatio(900_000);

        // Buyback
        vm.startPrank(user);
        simStable.buyback(simGovAmount);
        vm.stopPrank();
        assertEq(simGov.balanceOf(user), 0);
        assertEq(weth.balanceOf(user), wethBalance - 99 ether + 9 ether);

        // Expect the revert with InsufficientCollateral error
        vm.startPrank(user);
        vm.expectPartialRevert(SimStable.InsufficientCollateral.selector);
        simStable.buyback(simGovAmount);
        vm.stopPrank();
    }



    /**
     * @notice Tests the recollateralization process by adding collateral and receiving SimGov tokens.
     */
    function testReCollateralize() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);

        uint256 collateralAmount = 1 ether;
        uint256 simGovAmount = 1 * weth_price;
        mintSimGov(user, simGovAmount);
        uint256 userSimGovAmountBefore = simGov.balanceOf(user);

        // Mint
        vm.startPrank(user);
        simStable.mint(collateralAmount, simGovAmount);
        vm.stopPrank();

        setCollateralRatio(500_000);

        // reCollateralize
        vm.startPrank(user);
        simStable.reCollateralize(10 ether, 10 * weth_price);
        assertEq(userSimGovAmountBefore + (10 * weth_price), simGov.balanceOf(user));
        vm.expectPartialRevert(SimStable.TooMuchCollateral.selector);
        simStable.reCollateralize(10 ether, weth_price);
        vm.stopPrank();

    }






}
