// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/SimStable.sol";
import "../src/SimGov.sol";
import "../src/Vault.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    // Contracts
    SimStable public simStable;
    SimGov public simGov;
    Vault public vault;
    IWETH public weth;

    // Roles and addresses
    address public admin = address(0x1);
    address public user = address(0x2);
    address public dummyUser = address(0x3);

    // Constants
    uint256 public initialAdjustmentCoefficient = 2e5;
    uint256 public targetCollateralRatio = 900_000; // 90%
    uint256 public reCollateralizeTargetRatio = 600_000; // 60%
    uint256 public minCollateralRatio = 500_000; // 50%
    uint256 public collateralRatioAdjustmentCooldown = 600; // 10 minutes
    uint256 public maxCollateralMultiplier = 10; // 10 times collateral


    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant UNISWAP_ROUTERV02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    uint256 public constant SCALING_FACTOR = 1e6;

    function setUp() public virtual {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        weth = IWETH(WETH_ADDRESS);

        vm.startPrank(admin);

        // Deploy SimStable
        simStable = new SimStable(
            "SimStable",
            "SIM",
            WETH_ADDRESS,
            DAI_ADDRESS,
            initialAdjustmentCoefficient,
            targetCollateralRatio,
            reCollateralizeTargetRatio,
            minCollateralRatio,
            collateralRatioAdjustmentCooldown,
            UNISWAP_FACTORY,
            WETH_ADDRESS
        );

        // Deploy SimGov
        simGov = new SimGov(address(simStable), "SimGov", "SIMGOV");
        // Deploy Vault
        vault = new Vault(address(simStable));

        // Set SimGov and Vault addresses in SimStable
        simStable.setSimGov(address(simGov));
        simStable.setVault(address(vault));

        // Grant MINTER_ROLE to admin in SimGov for mint test
        simGov.grantRole(keccak256("MINTER_ROLE"), admin);

        vm.stopPrank();


        // Fund user with WETH
        vm.deal(user, 1_000 ether); // Assign 1000 ETH to user
        vm.startPrank(user);
        weth.approve(address(vault), type(uint256).max);
        weth.deposit{value: 100 ether}(); // Convert ETH to WETH
        vm.stopPrank();
        // Fund simStable with WETH
        vm.deal(address(simStable), 1_000 ether);
        vm.startPrank(address(simStable));
        weth.deposit{value: 100 ether}();  // Convert ETH to WETH
        vm.stopPrank();


        // Label addresses for easier debugging
        vm.label(admin, "Admin");
        vm.label(user, "User");
        vm.label(dummyUser, "dummyUser");
        vm.label(address(simStable), "SimStable");
        vm.label(address(simGov), "SimGov");
        vm.label(address(vault), "Vault");
        vm.label(WETH_ADDRESS, "WETH");
        vm.label(DAI_ADDRESS, "DAI");
        vm.label(UNISWAP_FACTORY, "UniswapFactory");
        vm.label(UNISWAP_ROUTERV02, "UniswapRouterV02");

    }

    /**
     * @notice Sets up initial liquidity pools on Uniswap V2 for SimStable and SimGov.
     */
    function _setupLiquidityPools(uint256 simStableWETH, uint256 simStableSIM, uint256 simGovWETH, uint256 simGovSIMGOV) internal {
        vm.startPrank(admin);

        // Approve WETH to be spent by SimStable and SimGov
        weth.approve(address(simStable), type(uint256).max);
        weth.approve(address(simGov), type(uint256).max);

        // Mint SimStable and SimGov tokens to admin for liquidity
        simGov.mint(admin, simGovSIMGOV);

        // Approve Uniswap Router to spend tokens
        simStable.approve(UNISWAP_ROUTERV02, simStableSIM);
        simGov.approve(UNISWAP_ROUTERV02, simGovSIMGOV);

        // Setup SimStable/WETH pool
        simStable.createUniswapV2SimStablePool(
            UNISWAP_ROUTERV02,
            simStableWETH,
            simStableSIM
        );
        // Setup SimGov/WETH pool
        simStable.createUniswapV2SimGovPool(
            UNISWAP_ROUTERV02,
            simGovWETH,
            simGovSIMGOV
        );

        vm.stopPrank();
    }


    function setupLiquidityPoolsDefault() internal {
        uint256 weth_price = simStable.getTokenPriceSpot(WETH_ADDRESS, DAI_ADDRESS);
        _setupLiquidityPools(1 ether, weth_price, 1 ether, weth_price);
    }


    modifier prankAdmin() {
        vm.startPrank(admin);
        _;
        vm.stopPrank();
    }

    function setCollateralRatio(uint256 _newCollateralRatio) internal prankAdmin {
        simStable.setCollateralRatio(_newCollateralRatio);
    }

    function mintSimGov(address to, uint256 amount) internal prankAdmin {
        simGov.mint(to, amount);
    }

    function performSwap(
        address router,
        address[] memory path,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) internal {
        IUniswapV2Router02(router).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            block.timestamp
        );
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }




}
