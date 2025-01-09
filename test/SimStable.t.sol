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













}
