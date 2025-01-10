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


    /**
     * @notice Tests dynamic collateral ratio adjustments based on SimStable price.
     */
    function testAdjustCollateralRatio_crDecrease() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = address(simStable);

        setCollateralRatio(950_000);
        assertEq(simStable.collateralRatio(), 950_000);

        uint256 ssPrice = (weth_price * 1e18) / simStable.getSimStablePrice();
        assertEq(ssPrice, 1e18);

        vm.startPrank(user);
        simStable.adjustCollateralRatio();
        ssPrice = (weth_price * 1e18) / simStable.getSimStablePrice();
        assertEq(ssPrice, 1e18);

        // swap eth for simStable
        weth.approve(UNISWAP_ROUTERV02, type(uint256).max);
        performSwap(
            UNISWAP_ROUTERV02,
            path,
            1e17, // 0.1 weth
            0,
            user
        );

        // simStable price is higher
        ssPrice = (weth_price * 1e18) / simStable.getSimStablePrice();
        assertGt(ssPrice, 1e18);

        // adjust
        vm.warp(block.timestamp + 600);
        simStable.adjustCollateralRatio();

        // expect cr decrease because price is higher
        assertLt(simStable.collateralRatio(), 950_000);

        vm.stopPrank();

    }

    function testAdjustCollateralRatio_crIncrease() public {
        setupLiquidityPoolsDefault();
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);
        address[] memory path = new address[](2);
        path[0] = address(simStable);
        path[1] = WETH_ADDRESS;

        uint256 ssPrice = (weth_price * 1e18) / simStable.getSimStablePrice();
        assertEq(ssPrice, 1e18);

        vm.startPrank(user);
        simStable.adjustCollateralRatio();
        ssPrice = (weth_price * 1e18) / simStable.getSimStablePrice();
        assertEq(ssPrice, 1e18);

        // mint simStable for swap
        simStable.mint(1e18, 0);
        vm.stopPrank();

        // set cr to lower than 100% so we can increase it
        setCollateralRatio(950_000);
        assertEq(simStable.collateralRatio(), 950_000);


        // swap eth for simStable
        vm.startPrank(user);
        simStable.approve(UNISWAP_ROUTERV02, type(uint256).max);
        performSwap(
            UNISWAP_ROUTERV02,
            path,
            300 * 1e18, // 300 $ simStable (10%)
            0,
            user
        );

        // simStable price is lower
        ssPrice = (weth_price * 1e18) / simStable.getSimStablePrice();
        assertLt(ssPrice, 1e18);

        // adjust
        vm.warp(block.timestamp + 600);
        simStable.adjustCollateralRatio();

        // expect cr decrease because price is higher
        assertGt(simStable.collateralRatio(), 950_000);

        vm.stopPrank();

    }



    /**
     * @notice Tests minting with insufficient SimGov tokens (should revert).
     */
    function testMintInsufficientSimGov() public {
        setupLiquidityPoolsDefault();
        setCollateralRatio(950_000); // 95%

        vm.startPrank(user);
        vm.expectPartialRevert(bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")));
        simStable.mint(1 ether, 0);
        vm.stopPrank();
    }

    /**
     * @notice Tests slippage protection during minting.
     */
    function testMintSlippageProtection() public {
        setupLiquidityPoolsDefault();

        // Attempt to mint with high minSimStableAmount (should revert)
        vm.startPrank(user);
        vm.expectPartialRevert(SimStable.SlippageExceeded.selector);
        simStable.mint(1 ether, 1e50);
        vm.stopPrank();
    }


    /**
     * @notice Tests redeeming more SimStable than user holds (should revert).
     */
    function testRedeemExcessSimStable() public {
        setupLiquidityPoolsDefault();

        // Attempt to redeem
        vm.startPrank(user);
        vm.expectPartialRevert(bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")));
        simStable.redeem(200_000 ether, 0, 0);
        vm.stopPrank();
    }


    /**
     * @notice Tests the adjustCollateralRatio function cooldown.
     */
    function testCollateralRatioAdjustmentCooldown() public {
        setupLiquidityPoolsDefault();
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = address(simStable);
        uint256 cr = simStable.collateralRatio();

        setCollateralRatio(950_000);

        vm.startPrank(user);
        weth.approve(UNISWAP_ROUTERV02, type(uint256).max);

        // swap eth for simStable
        performSwap(
            UNISWAP_ROUTERV02,
            path,
            1e17, // 0.1 weth
            0,
            user
        );

        // move time because uniswap transfer reset adjusment cooldown
        vm.warp(block.timestamp + 600);
        cr = simStable.collateralRatio();
        simStable.adjustCollateralRatio();
        // expect change
        assertNotEq(cr, simStable.collateralRatio());

        // swap eth for simStable
        performSwap(
            UNISWAP_ROUTERV02,
            path,
            1e17, // 0.1 weth
            0,
            user
        );

        cr = simStable.collateralRatio();
        simStable.adjustCollateralRatio();
        // do not expect change becasue cooldown
        assertEq(cr, simStable.collateralRatio());

        // expect change
        vm.warp(block.timestamp + 600);
        cr = simStable.collateralRatio();
        simStable.adjustCollateralRatio();
        // expect change
        assertNotEq(cr, simStable.collateralRatio());

        vm.stopPrank();    
    }




    /**
     * @notice Tests admin functions for setting parameters.
     */
    function testAdminFunctions() public {
        bytes4 err = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));

        // check for admin access control
        vm.startPrank(user);
 
        vm.expectPartialRevert(err);
        simStable.setCollateralRatio(800_000);
 
        vm.expectPartialRevert(err);
        simStable.setVault(address(0x1111));

        vm.expectPartialRevert(err);
        simStable.setSimGov(address(0x1111));

        vm.expectPartialRevert(err);
        simStable.setAdjustmentCoefficient(123);

        vm.expectPartialRevert(err);
        simStable.setCollateralToken(address(0x1111));

        vm.expectPartialRevert(err);
        simStable.setCollateralTokenPair(address(0x1111));

        vm.expectPartialRevert(err);
        simStable.setMinCollateralRatio(123);

        vm.expectPartialRevert(err);
        simStable.setMaxCollateralRatio(123);

        vm.expectPartialRevert(err);
        simStable.setMaxCollateralMultiplier(123);

        vm.expectPartialRevert(err);
        simStable.setCollateralRatioAdjustmentCooldown(123);

        vm.expectPartialRevert(err);
        simStable.createUniswapV2SimStablePool(address(0x1111), 123, 123);

        vm.expectPartialRevert(err);
        simStable.createUniswapV2SimGovPool(address(0x1111), 123, 123);

        vm.expectPartialRevert(err);
        simStable.addLiquidity(address(0x1111), address(0x1111), address(0x1111), 123, 123, address(0x1111));

        vm.stopPrank();



        // check admin functions other errors
        vm.startPrank(admin);
 
        vm.expectRevert(SimStable.ZeroAddress.selector);
        simStable.setVault(address(0x0));
        simStable.setVault(address(0x1111));
        assertEq(address(simStable.vault()), address(0x1111));

        vm.expectRevert(SimStable.ZeroAddress.selector);
        simStable.setSimGov(address(0x0));
        simStable.setSimGov(address(0x1111));
        assertEq(address(simStable.simGov()), address(0x1111));

        simStable.setAdjustmentCoefficient(123);
        assertEq(simStable.adjustmentCoefficient(), 123);

        simStable.setCollateralRatio(800_000);
        assertEq(simStable.collateralRatio(), 800_000);
        simStable.setCollateralRatio(1800_000);
        assertEq(simStable.collateralRatio(), SCALING_FACTOR);

        vm.expectRevert(SimStable.ZeroAddress.selector);
        simStable.setCollateralToken(address(0x0));
        simStable.setCollateralToken(address(0x1111));
        assertEq(simStable.collateralToken(), address(0x1111));

        vm.expectRevert(SimStable.ZeroAddress.selector);
        simStable.setCollateralTokenPair(address(0x0));
        simStable.setCollateralTokenPair(address(0x1111));
        assertEq(simStable.collateralTokenPair(), address(0x1111));

        uint256 maxCollateralRatio = simStable.maxCollateralRatio();
        vm.expectPartialRevert(SimStable.InvalidMinOrMaxCollateralRatioSet.selector);
        simStable.setMinCollateralRatio(maxCollateralRatio);
        simStable.setMinCollateralRatio(maxCollateralRatio - 1);
        assertEq(simStable.minCollateralRatio(), simStable.maxCollateralRatio() - 1);

        vm.expectPartialRevert(SimStable.InvalidMinOrMaxCollateralRatioSet.selector);
        simStable.setMaxCollateralRatio(SCALING_FACTOR + 1);
        uint256 minCollateralRatio = simStable.minCollateralRatio();
        vm.expectPartialRevert(SimStable.InvalidMinOrMaxCollateralRatioSet.selector);
        simStable.setMaxCollateralRatio(minCollateralRatio - 1);
        simStable.setMaxCollateralRatio(minCollateralRatio + 1);
        assertEq(simStable.maxCollateralRatio(), minCollateralRatio + 1);

        vm.expectRevert(SimStable.InvalidMaxCollateralMultiplier.selector);
        simStable.setMaxCollateralMultiplier(0);
        simStable.setMaxCollateralMultiplier(123);
        assertEq(simStable.maxCollateralMultiplier(), 123);

        simStable.setCollateralRatioAdjustmentCooldown(123);
        assertEq(simStable.collateralRatioAdjustmentCooldown(), 123);

        simStable.createUniswapV2SimStablePool(UNISWAP_ROUTERV02, 1 ether, 1 ether);
        vm.expectRevert(SimStable.PairAlreadyExists.selector);
        simStable.createUniswapV2SimStablePool(UNISWAP_ROUTERV02, 1, 1);

        vm.stopPrank();
    }


















}
