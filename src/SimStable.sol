// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// Import OpenZeppelin ERC20 implementation and AccessControl
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
// Import Uniswap V2 interfaces for price feeds
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
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
    mapping(address => address) public collateralToPair;

    // Errors
    error InvalidVaultAddress();
    error InvalidSimGovAddress();
    error InvalidCollateralAmount();
    error InvalidSimStableAmount();
    error InvalidSimGovAmount();
    error PriceFetchFailed();
    error CollateralRatioOutOfBounds();
    error InsufficientSimStableBalance();


    // Events
    event Minted(address indexed user, address indexed collateralToken, uint256 collateralAmount, uint256 collateralPrice, uint256 simStableAmount, uint256 collateralRatio, uint256 simGovAmount, uint256 simGovPrice);
    event Redeemed(address indexed user, address indexed collateralToken, uint256 simStableAmount, uint256 collateralAmount, uint256 collateralPrice, uint256 simGovAmount, uint256 simGovPrice, uint256 collateralRatio);
    event Buyback(address indexed user, uint256 simGovAmount, uint256 collateralUsed);
    event ReCollateralized(address indexed user, uint256 collateralAdded, uint256 simGovMinted);
    event CollateralRatioAdjusted(uint256 newCollateralRatio);
    event VaultUpdated(address newVault);
    event SimGovUpdated(address simGov);
    event CollateralPairAdded(address collateralToken, address pair);
    event CollateralPairRemoved(address collateralToken);
    error UnsupportedCollateralToken();

    // Constants
    uint256 private constant SCALING_FACTOR = 1e6;
    address private immutable UNISWAP_FACTORY;
    address private immutable WETH_ADDRESS;
    uint256 constant WAD = 1e18;



    /* ---------- CONSTRUCTOR ---------- */

    constructor(
        string memory _name,
        string memory _symbol,
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
    }


    /* ---------- CORE FUNCTIONS ---------- */

    /**
     * @notice Mints SimStable tokens by depositing collateral and burning SimGov tokens based on the collateral ratio.
     * @param _collateralToken The address of the collateral token.
     * @param _collateralAmount Amount of collateral to deposit.
     */
    function mint(address _collateralToken, uint256 _collateralAmount) external {
        // Ensure that the collateral amount is greater than zero
        if (_collateralAmount == 0) {
            revert InvalidCollateralAmount();
        }

        // Ensure that the collateral token is supported
        address pair = collateralToPair[_collateralToken];
        if (pair == address(0)) {
            revert UnsupportedCollateralToken();
        }

        // Fetch the price of the collateral token
        uint256 collateralPrice = getTokenPrice(_collateralToken, pair);
        if (collateralPrice == 0) {
            revert PriceFetchFailed();
        }

        // Fetch the price of SimGov token
        uint256 simGovPrice = getSimGovPrice();
        if (simGovPrice == 0) {
            revert PriceFetchFailed();
        }

        // Calculate the value of the collateral
        uint256 collateralValue = _collateralAmount * collateralPrice / WAD;

        // Calculate the required SimStable amount based on collateral ratio
        // collateralValue = CR * simStableAmount => simStableAmount = collateralValue / CR
        uint256 simStableAmount = (collateralValue * SCALING_FACTOR) / collateralRatio;
        if (simStableAmount == 0) {
            revert InvalidSimStableAmount();
        }

        // Calculate the required SimGov amount to back the remaining (1 - CR) portion
        // simGovValue = (1 - CR) * simStableAmount
        uint256 simGovValue = ((simStableAmount * (SCALING_FACTOR - collateralRatio)) / SCALING_FACTOR);
        // simGovValue = simGovAmount * simGovPrice
        uint256 simGovAmount = simGovValue * WAD / simGovPrice;

        // TODO: add slippage

        // Transfer collateral from user to Vault
        vault.depositCollateral(_collateralToken, msg.sender, _collateralAmount);

        // Burn SimGov tokens from user
        if (simGovAmount > 0) {
            simGov.burn(msg.sender, simGovAmount);
        }

        // Mint SimStable to user
        _mint(msg.sender, simStableAmount);

        // Emit a comprehensive event with all relevant information
        emit Minted(
            msg.sender,
            _collateralToken,
            _collateralAmount,
            collateralPrice,
            simStableAmount,
            collateralRatio,
            simGovAmount,
            simGovPrice
        );
    }


    /**
     * @notice Redeems SimStable tokens for collateral and mints SimGov tokens based on the collateral ratio.
     * @param _collateralToken The address of the collateral token.
     * @param _simStableAmount Amount of SimStable tokens to redeem.
     */
    function redeem(address _collateralToken, uint256 _simStableAmount) external {
        // Check if the provided SimStable amount is valid (greater than zero)
        if (_simStableAmount == 0) {
            revert InvalidSimStableAmount();
        }

        // Fetch the price of the collateral token
        address pair = collateralToPair[_collateralToken];
        if (pair == address(0)) {
            revert UnsupportedCollateralToken();
        }

        // Fetch the price of the collateral token
        uint256 collateralPrice = getTokenPrice(_collateralToken, pair);
        if (collateralPrice == 0) {
            revert PriceFetchFailed();
        }

        // Fetch the price of SimGov token
        uint256 simGovPrice = getSimGovPrice();
        if (simGovPrice == 0) {
            revert PriceFetchFailed();
        }

        // Calculate the required collateral and SimGov amounts based on collateral ratio
        // collateralValue = CR * simStableAmount
        uint256 collateralValue = (_simStableAmount * collateralRatio) / SCALING_FACTOR;
        uint256 collateralAmount = (collateralValue * WAD) / collateralPrice;

        // simGovValue = (1 - CR) * simStableAmount
        uint256 simGovValue = (_simStableAmount * (SCALING_FACTOR - collateralRatio)) / SCALING_FACTOR;
        // simGovValue = simGovAmount * simGovPrice
        uint256 simGovAmount = (simGovValue * WAD) / simGovPrice;

        // TODO: add slippage

        // Burn SimStable tokens from user
        _burn(msg.sender, _simStableAmount);

        // Transfer collateral from Vault to user
        vault.withdrawCollateral(_collateralToken, msg.sender, collateralAmount);

        // Mint SimGov tokens to user
        simGov.mint(msg.sender, simGovAmount);

        emit Redeemed(msg.sender, _collateralToken, _simStableAmount, collateralAmount, collateralPrice, simGovAmount, simGovPrice, collateralRatio);
    }


    function buybackSimGov(uint256 simGovAmount) external {
    }


    function reCollateralize(uint256 collateralAdded) external {
    }






    /* ---------- INTERNAL ---------- */

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
        return getTokenPriceSpot(tokenA, tokenB);
    }
        

    /**
     * @notice Fetches the spot price of a token pair from Uniswap V2.
     * @dev This function calculates the price of `tokenA` in terms of `tokenB` based on the reserves of the pair contract. The price is scaled by 1e18 for precision.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @return price The price of `tokenA` denominated in `tokenB`, scaled by 1e18.
     */
    function getTokenPriceSpot(address tokenA, address tokenB) internal view returns (uint price) {
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
        return WAD; // TODO: remove
        return getTokenPrice(WETH_ADDRESS, address(simGov));
    }




    /* ---------- ADMIN FUNCTIONS ---------- */

    /**
     * @notice Sets a new Vault address.
     * @param _newVault New Vault address.
     */
    function setVault(address _newVault) external onlyRole(ADMIN_ROLE) {
        if (_newVault == address(0)) {
            revert InvalidVaultAddress();
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
            revert InvalidSimGovAddress();
        }
        simGov = ISimGov(_simGov);
        emit SimGovUpdated(_simGov);
    }

    /**
     * @notice Adds a new collateral token and its Uniswap V2 pair.
     * @param _collateralToken The address of the collateral token.
     * @param _pair The address of the Uniswap V2 pair for the collateral token.
     */
    function addCollateralToken(address _collateralToken, address _pair) external onlyRole(ADMIN_ROLE) {
        require(_collateralToken != address(0), "Invalid collateral token");
        collateralToPair[_collateralToken] = _pair;
        emit CollateralPairAdded(_collateralToken, _pair);
    }

    /**
     * @notice Removes a collateral token and its Uniswap V2 pair.
     * @param _collateralToken The address of the collateral token to remove.
     */
    function removeCollateralToken(address _collateralToken) external onlyRole(ADMIN_ROLE) {
        delete collateralToPair[_collateralToken];
        emit CollateralPairRemoved(_collateralToken);
    }

    /**
     * @notice Sets a new adjustment coefficient.
     * @param _newAdjustmentCoefficient New adjustment coefficient scaled by 1e6.
     */
    function setAdjustmentCoefficient(uint256 _newAdjustmentCoefficient) external onlyRole(ADMIN_ROLE) {
        adjustmentCoefficient = _newAdjustmentCoefficient;
    }

    // for test
    // TODO: deside for removal or not. maybe emergency set
    function setCollateralRatio(uint256 _newCollateralRatio) external onlyRole(ADMIN_ROLE) {
        if (_newCollateralRatio > SCALING_FACTOR) _newCollateralRatio = _newCollateralRatio;
        collateralRatio = _newCollateralRatio;
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


