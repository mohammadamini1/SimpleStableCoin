// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "../src/SimStable.sol";
import "../src/SimGov.sol";
import "../src/Vault.sol";
import "../src/interface/ISimGov.sol";
import "../src/interface/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function approve(address spender, uint value) external returns (bool);
}

contract DeployScript is Script {
    using stdJson for string;

    // Addresses
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;  // DAI
    address constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Uniswap V2 Factory
    address constant UNISWAP_ROUTER02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router02

    //// holesky address are different
    // address constant WETH_ADDRESS = 0x94373a4919B3240D86eA41593D5eBa789FEF3848; // WETH
    // address constant DAI_ADDRESS = 0x4B0D4183df9D6664369b228e1682Ecade35bE6F3;  // DAI
    // address constant UNISWAP_FACTORY = ?; // Uniswap V2 Factory
    // address constant UNISWAP_ROUTER02 = ?; // Uniswap V2 Router02


    // Deployment Parameters
    string constant SIMSTABLE_NAME = "SimStable";
    string constant SIMSTABLE_SYMBOL = "SIM";
    string constant SIMGOV_NAME = "SimGov";
    string constant SIMGOV_SYMBOL = "SIMGOV";

    uint256 constant INITIAL_ADJUSTMENT_COEFFICIENT = 200_000;
    uint256 constant TARGET_COLLATERAL_RATIO = 900_000;
    uint256 constant RE_COLLATERALIZE_TARGET_RATIO = 600_000;
    uint256 constant MIN_COLLATERAL_RATIO = 500_000;
    uint256 constant COLLATERAL_RATIO_ADJUSTMENT_COOLDOWN = 600;
    uint256 constant MAX_COLLATERAL_MULTIPLIER = 10;

    // Addresses for deployment
    address admin = vm.envAddress("DEPLOYER_ADDRESS");

    function run() external {
        // Start broadcasting transactions
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy SimStable
        SimStable simStable = new SimStable(
            SIMSTABLE_NAME,
            SIMSTABLE_SYMBOL,
            WETH_ADDRESS,
            DAI_ADDRESS,
            INITIAL_ADJUSTMENT_COEFFICIENT,
            TARGET_COLLATERAL_RATIO,
            RE_COLLATERALIZE_TARGET_RATIO,
            MIN_COLLATERAL_RATIO,
            COLLATERAL_RATIO_ADJUSTMENT_COOLDOWN,
            UNISWAP_FACTORY,
            WETH_ADDRESS
        );
        console.log("SimStable deployed at:", address(simStable));

        // Deploy SimGov
        SimGov simGov = new SimGov(
            address(simStable),
            SIMGOV_NAME,
            SIMGOV_SYMBOL
        );
        console.log("SimGov deployed at:", address(simGov));

        // Deploy Vault
        Vault vault = new Vault(address(simStable));
        console.log("Vault deployed at:", address(vault));

        // Set SimGov and Vault addresses in SimStable
        simStable.setSimGov(address(simGov));
        simStable.setVault(address(vault));
        console.log("SimGov and Vault addresses set in SimStable");



        // convert eth to weth
        IWETH(WETH_ADDRESS).deposit{ value: 0.2 ether }();
        // transfer to simStable
        IWETH(WETH_ADDRESS).transfer(address(simStable), 0.2 ether);


        // TODO: update address for testnet first and then uncomment
        // Create Uniswap V2 Pool for WETH/SimStable
        // uint256 weth_price = simStable.getTokenPrice(WETH_ADDRESS, DAI_ADDRESS);
        uint256 weth_price = 3500 ether;

        // console.log("WETH price during deployment:", weth_price);
        // simStable.createUniswapV2SimStablePool(
        //     UNISWAP_ROUTER02,
        //     0.1 ether,
        //     weth_price / 10 // 1 $
        // );
        // console.log("Uniswap V2 Pool for WETH/SimStable created");

        // // Create Uniswap V2 Pool for WETH/SimGov
        // simStable.createUniswapV2SimGovPool(
        //     UNISWAP_ROUTER02,
        //     0.1 ether,
        //     weth_price / 100 // 0.1 $
        // );
        // console.log("Uniswap V2 Pool for WETH/SimGov created");

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
