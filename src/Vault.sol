// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import OpenZeppelin libraries
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault is AccessControl {
    using SafeERC20 for IERC20;
    
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIMSTABLE_CONTRACT_ROLE = keccak256("SIMSTABLE_CONTRACT_ROLE");

    // Collateral token address
    IERC20 public collateralToken;
    IERC20 public simStableAddress;

    // Errors
    error InvalidCollateralTokenAddress();
    error InvalidSimStableTokenAddress();
    error InvalidDepositAmount();
    error UnauthorizedCaller();

    // Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);



    /* ---------- MODIFIERS ---------- */
    modifier onlySimStableRole() {
        if (!hasRole(SIMSTABLE_CONTRACT_ROLE, _msgSender())) {
            revert UnauthorizedCaller();
        }
        _;
    }




    /* ---------- CONSTRUCTOR ---------- */
    constructor(address _collateralToken, address _simStableAddress) {
        // Check for the zero address.
        if (_collateralToken == address(0)) {
            revert InvalidCollateralTokenAddress();
        }
        if (_simStableAddress == address(0)) {
            revert InvalidSimStableTokenAddress();
        }

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SIMSTABLE_CONTRACT_ROLE, _simStableAddress);

        // initialize state variables
        collateralToken = IERC20(_collateralToken);
        simStableAddress = IERC20(_simStableAddress);
    }


    /**
     * @notice Deposits collateral into the Vault.
     * @param user The address of the user depositing collateral.
     * @param amount Amount of collateral to deposit.
     */
    function depositCollateral(address user, uint256 amount) external onlySimStableRole {
        // Check if the deposit amount is greater than zero
        if (amount == 0) {
            revert InvalidDepositAmount();
        }

        // Transfer collateral tokens from the user to this contract
        collateralToken.safeTransferFrom(user, address(this), amount);

        emit CollateralDeposited(user, amount);
    }





}


