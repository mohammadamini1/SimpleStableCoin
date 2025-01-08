// contracts/test/BaseTest.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import Foundry's Test base contract
import "forge-std/Test.sol";

// Import the contracts
import "../src/SimStable.sol";
import "../src/SimGov.sol";
import "../src/Vault.sol";




interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function approve(address spender, uint value) external returns (bool);
    function balanceOf(address user) external returns (uint256);
}


/**
 * @title BaseTest
 * @notice A base test contract that deploys and initializes all necessary contracts for testing.
 */
contract BaseTest is Test {
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    SimStable public simStable;
    SimGov public simGov;
    Vault public vault;

    address public admin = address(0x1);
    address public user = address(0x2);

    uint256 public initialAdjustmentCoefficient = 1; // Example value

    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_ROUTERV02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    IWETH weth = IWETH(WETH_ADDRESS);


    /**
     * @notice Initializes the test environment by deploying and setting up all contracts.
     */
    function setUp() public virtual {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        // Assign roles to admin
        vm.startPrank(admin);

        // Deploy SimStable
        simStable = new SimStable("SimStable", "SIM", WETH_ADDRESS, DAI_ADDRESS, initialAdjustmentCoefficient, UNISWAP_FACTORY, WETH_ADDRESS);

        // Deploy SimGov
        simGov = new SimGov(address(simStable), "SimGov", "SIMGOV");

        // Deploy Vault
        vault = new Vault(address(simStable));

        // Set SimGov and Vault addresses in SimStable
        simStable.setSimGov(address(simGov));
        simStable.setVault(address(vault));

        // mint simGov for user to test
        simGov.grantRole(keccak256("MINTER_ROLE"), admin);
        simGov.mint(user, 100_000 ether);

        vm.stopPrank();


        // initialize pools
        // fund simStable some weth
        vm.deal(address(simStable), 100 ether);
        vm.startPrank(address(simStable));
        weth.deposit{value: 10 ether}();
        vm.stopPrank();
        // create uniswap pair
        vm.label(UNISWAP_FACTORY, "UNISWAP_FACTORY");
        vm.label(UNISWAP_ROUTERV02, "uniswapRouterV02");
        vm.startPrank(address(admin));
        uint bprice = 3338369172050483971226;
        simStable.createUniswapV2SimStablePool(
            UNISWAP_ROUTERV02,
            1 * 10**18,
            // 3347 * 10**18
            // 6600 * 10**18
            // 1800 * 10**18
            bprice * 1
        );
        simStable.createUniswapV2SimGovPool(
            UNISWAP_ROUTERV02,
            1 * 10**18,
            // 33470 * 10**18
            bprice * 10
        );
        vm.stopPrank();


        // mint weth to user
        vm.deal(user, 100 ether);
        vm.startPrank(user);
        weth.approve(address(vault), type(uint256).max);
        weth.deposit{value: 1 ether}();
        vm.stopPrank();


        // label addresses
        vm.label(admin, "Admin");
        vm.label(user, "User");
        vm.label(address(simStable), "simStable");
        vm.label(address(simGov), "simGov");
        vm.label(address(vault), "vault");
        vm.label(WETH_ADDRESS, "WETH");
        vm.label(UNISWAP_FACTORY, "UNISWAP_FACTORY");


    }






}
