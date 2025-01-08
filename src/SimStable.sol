// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// Import OpenZeppelin ERC20 implementation and AccessControl
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
// Import Uniswap V2 interfaces for price feeds
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
// Import interfaces
import "./interface/IVault.sol";
import "./interface/ISimGov.sol";



// TODO: override transfer and transferfrom
// TODO: add simulation functions to calculate simStable amount for mint or redeem

contract SimStable is ERC20, AccessControl {
    // Roles
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // SimGov token address
    ISimGov simGov;

    // Vault contract
    IVault public vault;

    // Collateral Ratio (scaled by 1e6, e.g., 750000 for 75%)
    uint256 public collateralRatio;

    // Price adjustment coefficient (k, scaled by 1e6)
    uint256 public adjustmentCoefficient;

    // Uniswap V2 Pair Addresses for Collateral Tokens
    address public collateralToken;
    address public collateralTokenPair;

    // Errors
    error ZeroAddress();
    error InvalidCollateralAmount();
    error InvalidSimStableAmount();
    error InvalidSimGovAmount();
    error PriceFetchFailed();
    error PairCreationFailed();
    error PairAlreadyExists();
    error SlippageExceeded(uint256 expected, uint256 actual);

    // Events
    event Minted(address indexed user, uint256 collateralAmount, uint256 collateralPrice, uint256 simStableAmount, uint256 simStablePrice, uint256 simGovAmount, uint256 simGovPrice, uint256 collateralRatio);
    // event Redeemed(address indexed user, uint256 collateralAmount, uint256 collateralPrice, uint256 simStableAmount, uint256 simStablePrice, uint256 simGovAmount, uint256 simGovPrice, uint256 collateralRatio);
    event Redeemed(address indexed user, uint256 collateralAmount, uint256 simStableAmount, uint256 simGovAmount, uint256 collateralRatio);
    event Buyback(address indexed user, uint256 simGovAmount, uint256 collateralUsed);
    event ReCollateralized(address indexed user, uint256 collateralAdded, uint256 simGovMinted);
    event CollateralRatioAdjusted(uint256 newCollateralRatio);
    event VaultUpdated(address newVault);
    event SimGovUpdated(address simGov);
    event CollateralTokenUpdated(address newCollateralToken);
    event CollateralTokenPairUpdated(address newCollateralTokenPair);
    event AdjustmentCoefficientUpdated(uint256 newAdjustmentCoefficient);
    event CollateralPairAdded(address collateralToken, address pair);
    event CollateralPairRemoved(address collateralToken);
    event LiquidityAdded(address tokenA, address tokenB, uint256 amountA, uint256 amountB, address pairAddress);
    event PairCreated(address indexed tokenA, address indexed tokenB, address pair);

    // Constants
    uint256 private constant SCALING_FACTOR = 1e6;
    address private immutable UNISWAP_FACTORY;
    address private immutable WETH_ADDRESS;
    uint256 private constant WAD = 1e18;



    /* ---------- CONSTRUCTOR ---------- */

    constructor(
        string memory _name,
        string memory _symbol,
        address _collateralToken,
        address _collateralTokenPair,
        uint256 _adjustmentCoeff,
        address _uniswapFactoryAddress,
        address _wethAddress
    ) ERC20(_name, _symbol) {
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());

        // Initialize parameters
        collateralRatio = SCALING_FACTOR; // 100% at first
        adjustmentCoefficient = _adjustmentCoeff;

        UNISWAP_FACTORY = _uniswapFactoryAddress;
        WETH_ADDRESS = _wethAddress;

        collateralToken = _collateralToken;
        collateralTokenPair = _collateralTokenPair;
    }


    /* ---------- CORE FUNCTIONS ---------- */

    /**
     * @notice Mints SimStable tokens by depositing collateral and burning SimGov tokens based on the collateral ratio.
     * @param _collateralAmount Amount of collateral to deposit.
     * @param _minSimStableAmount The minimum amount of SimStable tokens that must be minted. Reverts if slippage exceeds this amount.
     */
    function mint(uint256 _collateralAmount, uint256 _minSimStableAmount) external {
        // Ensure that the collateral amount is greater than zero
        if (_collateralAmount == 0) {
            revert InvalidCollateralAmount();
        }

        // Fetch the price of the collateral token
        uint256 collateralPrice = getTokenPrice(collateralToken, collateralTokenPair);

        // Fetch the price of SimGov token (in WETH)
        uint256 simGovPrice = getSimGovPrice();

        // Fetch the price of SimStable token (in WETH)
        uint256 simStablePrice = getSimStablePrice();

        // Calculate the value of the collateral based on collateral price
        uint256 collateralValue = (_collateralAmount * collateralPrice) / WAD;

        // Calculate the value of the simStable based on collateral ratio
        // simStableValue * CR = collateralValue
        uint256 simStableValue = (collateralValue * SCALING_FACTOR) / collateralRatio;

        // Calculate the required SimGov value to back the remaining (1 - CR) portion
        // simStableValue * (100% - CR) = simGovValue
        uint256 simGovValue = (simStableValue * (SCALING_FACTOR - collateralRatio)) / SCALING_FACTOR;


        // Calculate the required SimGov amount
        // simGovPricePair (based in pair($)) = ETH (based on pair($)) / simGovPrice (based on ETH)
        uint256 simGovPricePair = (collateralPrice * WAD) / simGovPrice;
        // simGovValue = simGovPrice * simGovAmount
        uint256 simGovAmount = (simGovValue * WAD) / simGovPricePair;

        // Calculate the required SimStable amount
        // simStablePricePair (based in pair($)) = ETH (based on pair($)) / simStablePrice (based on ETH)
        uint256 simStablePricePair = (collateralPrice * WAD) / simStablePrice;
        // simStableValue = simStablePrice * simStableAmount
        uint256 simStableAmount = (simStableValue * WAD) / simStablePricePair;
        if (simStableAmount == 0) {
            revert InvalidSimStableAmount();
        }

        // Check for slippage
        _checkSlippage(simStableAmount, _minSimStableAmount);

        // Transfer collateral from user to Vault
        vault.depositCollateral(collateralToken, _msgSender(), _collateralAmount);

        // Burn SimGov tokens from user
        if (simGovAmount > 0) {
            simGov.burn(_msgSender(), simGovAmount);
        }

        // Mint SimStable to user
        _mint(_msgSender(), simStableAmount);

        // Emit an event with minimum relevant information (because stack too deep error)
        emit Minted(_msgSender(), _collateralAmount, collateralPrice, simStableAmount, simStablePricePair, simGovAmount, simGovPricePair, collateralRatio);
    }


    /**
     * @notice Redeems SimStable tokens for collateral and mints SimGov tokens based on the collateral ratio.
     * @param _simStableAmount Amount of SimStable tokens to redeem.
     * @param _minCollateralAmount The minimum amount of collateral tokens that must be returned to the user. Reverts if slippage exceeds this amount.
     * @param _minSimGovAmount The minimum amount of SimGov tokens that must be minted to the user. Reverts if slippage exceeds this amount.
     */
    function redeem(uint256 _simStableAmount, uint256 _minCollateralAmount, uint256 _minSimGovAmount) external {
        // Check if the provided SimStable amount is valid
        if (_simStableAmount == 0) {
            revert InvalidSimStableAmount();
        }

        // Fetch the price of the collateral token
        uint256 collateralPrice = getTokenPrice(collateralToken, collateralTokenPair);

        // Fetch the price of SimGov token (in WETH)
        uint256 simGovPrice = getSimGovPrice();

        // Fetch the price of SimStable token (in WETH)
        uint256 simStablePrice = getSimStablePrice();

        // Calculate the value of the simStable based on price
        // simStablePricePair (based in pair($)) = ETH (based on pair($)) / simStablePrice (based on ETH)
        uint256 simStablePricePair = (collateralPrice * WAD) / simStablePrice;
        // simStableValue = simStablePrice * simStableAmount
        uint256 simStableValue = (simStablePricePair * _simStableAmount) / WAD;

        // Calculate the value of the collateral based on collateral ratio
        uint256 collateralValue = (simStableValue * collateralRatio) / SCALING_FACTOR;

        // Calculate the value of SimGov based on collateral price
        uint256 simGovValue = (simStableValue * (SCALING_FACTOR - collateralRatio)) / SCALING_FACTOR;


        // Calculate the amount of the collateral based on collateral price
        uint256 collateralAmount = (collateralValue * WAD) / collateralPrice;
        // Calculate the required SimGov amount
        uint256 simGovPricePair = (collateralPrice * WAD) / simGovPrice;
        uint256 simGovAmount = (simGovValue * WAD) / simGovPricePair;

        // Check for slippage
        _checkSlippage(collateralAmount, _minCollateralAmount);
        _checkSlippage(simGovAmount, _minSimGovAmount);

        // Burn SimStable tokens from user
        _burn(_msgSender(), _simStableAmount);

        // Transfer collateral from Vault to user
        vault.withdrawCollateral(collateralToken, _msgSender(), collateralAmount);

        // Mint SimGov tokens to user
        simGov.mint(_msgSender(), simGovAmount);

        // Emit an event with minimum relevant information (because stack too deep error)
        // emit Redeemed(_msgSender(), collateralAmount, collateralPrice, _simStableAmount, simStablePricePair, simGovAmount, simGovPricePair, collateralRatio);
        emit Redeemed(_msgSender(), collateralAmount, _simStableAmount, simGovAmount, collateralRatio);
    }


    function buybackSimGov(uint256 simGovAmount) external {
    }


    function reCollateralize(uint256 collateralAdded) external {
    }






    /* ---------- VIEW ---------- */

    /**
     * @notice Retrieves the current price of a token from its Uniswap V2 pair.
     * @dev This function acts as a wrapper for `getTokenPriceSpot` and is intended to support
     *      time-weighted average price (TWAP) calculations in the future. Currently, it fetches
     *      the spot price of the token pair.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @return price The price of `tokenA` denominated in `tokenB`, scaled by 1e18.
     */
    // TODO: implement TWAP
    function getTokenPrice(address tokenA, address tokenB) internal view returns (uint price) {
        price = getTokenPriceSpot(tokenA, tokenB);
        if (price == 0) {
            revert PriceFetchFailed();
        }
    }


    /**
     * @notice Fetches the spot price of a token pair from Uniswap V2.
     * @dev This function calculates the price of `tokenA` in terms of `tokenB` based on the reserves of the pair contract. The price is scaled by 1e18 for precision.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @return price The price of `tokenA` denominated in `tokenB`, scaled by 1e18.
     */
    function getTokenPriceSpot(address tokenA, address tokenB) public view returns (uint price) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        IUniswapV2Pair pair = IUniswapV2Pair(pairFor(UNISWAP_FACTORY, token0, token1));
        (uint reserve0, uint reserve1,) = pair.getReserves();

        // Calculate price based on reserves
        if (token0 == tokenA) {
            price = reserve1 * (10 ** 18) / reserve0;
        } else {
            price = reserve0 * (10 ** 18) / reserve1;
        }
    }

    /**
     * @notice Retrieves the current price of the SimGov token.
     * @dev This function fetch the price of SimGov in terms of WETH.
     * @return price The price of the SimGov token.
     */
    function getSimGovPrice() public view returns (uint256) {
        // return WAD; // TODO: remove
        return getTokenPrice(WETH_ADDRESS, address(simGov));
    }


    /**
     * @notice Retrieves the current price of the SimStable token.
     * @dev This function fetch the price of SimStable in terms of WETH.
     * @return price The price of the SimGov token.
     */
    function getSimStablePrice() public view returns (uint256) {
        // return WAD; // TODO: remove
        return getTokenPrice(WETH_ADDRESS, address(this));
    }


    function _checkSlippage(
        uint256 expected,
        uint256 actual
    ) internal pure {
        if (expected < actual) {
            revert SlippageExceeded(expected, actual);
        }
    }





    /* ---------- ADMIN FUNCTIONS ---------- */

    /**
     * @notice Sets a new Vault address.
     * @param _newVault New Vault address.
     */
    function setVault(address _newVault) external onlyRole(ADMIN_ROLE) {
        if (_newVault == address(0)) {
            revert ZeroAddress();
        }
        vault = IVault(_newVault);
        emit VaultUpdated(_newVault);
    }

    /**
     * @notice Sets simGov address.
     * @param _simGov simGov address.
     */
    function setSimGov(address _simGov) external onlyRole(ADMIN_ROLE) {
        if (_simGov == address(0)) {
            revert ZeroAddress();
        }
        simGov = ISimGov(_simGov);
        emit SimGovUpdated(_simGov);
    }

    /**
     * @notice Sets a new adjustment coefficient.
     * @param _newAdjustmentCoefficient New adjustment coefficient scaled by 1e6.
     */
    function setAdjustmentCoefficient(uint256 _newAdjustmentCoefficient) external onlyRole(ADMIN_ROLE) {
        adjustmentCoefficient = _newAdjustmentCoefficient;
        emit AdjustmentCoefficientUpdated(_newAdjustmentCoefficient);
    }

    // for test
    // TODO: decide for removal or not. maybe emergency set
    function setCollateralRatio(uint256 _newCollateralRatio) external onlyRole(ADMIN_ROLE) {
        if (_newCollateralRatio > SCALING_FACTOR) _newCollateralRatio = _newCollateralRatio;
        collateralRatio = _newCollateralRatio;
    }

    /**
     * @notice Updates the address of the collateral token.
     * @param _newCollateralToken The new address for the collateral token.
     */
    function setCollateralToken(address _newCollateralToken) external onlyRole(ADMIN_ROLE) {
        if (_newCollateralToken == address(0)) {
            revert ZeroAddress();
        }
        collateralToken = _newCollateralToken;
        emit CollateralTokenUpdated(_newCollateralToken);
    }

    /**
     * @notice Updates the address of the collateral token pair.
     * @param _newCollateralTokenPair The new address for the collateral token pair.
     */
    function setCollateralTokenPair(address _newCollateralTokenPair) external onlyRole(ADMIN_ROLE) {
        if (_newCollateralTokenPair == address(0)) {
            revert ZeroAddress();
        }
        collateralTokenPair = _newCollateralTokenPair;
        emit CollateralTokenPairUpdated(_newCollateralTokenPair);
    }


    /**
     * @notice Creates a Uniswap V2 liquidity pool for the WETH and SimStable token pair.
     * @param uniswapRouter Address of the Uniswap V2 router contract.
     * @param initialWETHAmount Initial amount of WETH to provide as liquidity.
     * @param initialSimStableAmount Initial amount of SimStable to provide as liquidity.
     *
    */
    function createUniswapV2SimStablePool(address uniswapRouter, uint256 initialWETHAmount, uint256 initialSimStableAmount) external onlyRole(ADMIN_ROLE) {
        IUniswapV2Factory factory = IUniswapV2Factory(UNISWAP_FACTORY);

        // Create WETH/SimStable Pool
        address simStableAddr = address(this);

        // Check if the WETH/SimStable pair already exists
        address pairSimStable = factory.getPair(WETH_ADDRESS, simStableAddr);
        if (pairSimStable == address(0)) {
            // Create the pair
            pairSimStable = factory.createPair(WETH_ADDRESS, simStableAddr);
            if (pairSimStable == address(0)) {
                revert PairCreationFailed();
            }
            // Emit event for pair creation
            emit PairCreated(WETH_ADDRESS, simStableAddr, pairSimStable);
        } else {
            revert PairAlreadyExists();
        }

        // // Mint simStable and approve router
        // _mint(address(this), initialSimStableAmount);

        addLiquidity(uniswapRouter, WETH_ADDRESS, simStableAddr, initialWETHAmount, initialSimStableAmount, pairSimStable);
    }


    /**
     * @notice Creates a Uniswap V2 liquidity pool for the WETH and SimGov token pair.
     * @param uniswapRouter Address of the Uniswap V2 router contract.
     * @param initialWETHAmount Initial amount of WETH to provide as liquidity.
     * @param initialSimGovAmount Initial amount of SimGov to provide as liquidity.
     */
    function createUniswapV2SimGovPool(address uniswapRouter, uint256 initialWETHAmount, uint256 initialSimGovAmount) external onlyRole(ADMIN_ROLE) {
        IUniswapV2Factory factory = IUniswapV2Factory(UNISWAP_FACTORY);

        // Create WETH/SimGov Pool
        address simGovAddr = address(simGov);
        if (simGovAddr == address(0)) {
            revert ZeroAddress();
        }

        // Check if the WETH/SimGov pair already exists
        address pairSimGov = factory.getPair(WETH_ADDRESS, simGovAddr);
        if (pairSimGov == address(0)) {
            // Create the pair
            pairSimGov = factory.createPair(WETH_ADDRESS, simGovAddr);
            if (pairSimGov == address(0)) {
                revert PairCreationFailed();
            }
            // Emit event for pair creation
            emit PairCreated(WETH_ADDRESS, simGovAddr, pairSimGov);
        } else {
            revert PairAlreadyExists();
        }

        // Mint simgov
        simGov.mint(address(this), initialSimGovAmount);

        addLiquidity(uniswapRouter, WETH_ADDRESS, simGovAddr, initialWETHAmount, initialSimGovAmount, pairSimGov);
    }

    /**
     * @notice Adds liquidity to a Uniswap V2 pool.
     * @param uniswapRouter The address of the Uniswap V2 router.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @param amountA The amount of the first token to add as liquidity.
     * @param amountB The amount of the second token to add as liquidity.
     */
    function addLiquidity(
        address uniswapRouter,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address pairAddress
    ) public onlyRole(ADMIN_ROLE) {
        if (tokenB == address(this)) {
            _mint(address(this), amountB);
        }

        // Approve Uniswap router to spend tokens
        IERC20(tokenA).approve(address(uniswapRouter), amountA);
        IERC20(tokenB).approve(address(uniswapRouter), amountB);

        // Add liquidity
        IUniswapV2Router02(uniswapRouter).addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            0, // TODO: slippage
            0,
            address(this),
            block.timestamp
        );

        // Emit liquidity addition event
        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, pairAddress);
    }











    /* ---------- UNISWAP MODIFIED FUNCTIONS ---------- */

    /*
     * These functions are adapted from the Uniswap V2 library to maintain compatibility with Solidity ^0.8.0.
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
    // calculates the CREATE2 address for a pair without making any external calls
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


