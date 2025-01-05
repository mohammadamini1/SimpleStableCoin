// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import OpenZeppelin libraries
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vault is AccessControl {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant SIMSTABLE_CONTRACT_ROLE = keccak256("SIMSTABLE_CONTRACT_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Errors
    error InvalidSimStableTokenAddress();
    error InvalidDepositAmount();
    error InvalidWithdrawAmount();

    // Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CollateralTokenUpdated(address newCollateralToken);






    /* ---------- CONSTRUCTOR ---------- */

    /**
     * @notice Initializes the Vault contract with the specified SIMStable token address.
     * @param _simStableAddress The address of the SIMStable token to be associated with the Vault.
     */
    constructor(address _simStableAddress) {
        // Check for the zero address.
        if (_simStableAddress == address(0)) {
            revert InvalidSimStableTokenAddress();
        }

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        _grantRole(SIMSTABLE_CONTRACT_ROLE, _simStableAddress);
    }



    /* ---------- EXTERNALS ---------- */


    /**
     * @notice Deposits collateral into the Vault.
     * @param _collateralToken The address of the collateral token.
     * @param user The address of the user depositing collateral.
     * @param amount Amount of collateral to deposit.
     */
    function depositCollateral(address _collateralToken, address user, uint256 amount) external onlyRole(SIMSTABLE_CONTRACT_ROLE) {
        // Check if the deposit amount is greater than zero
        if (amount == 0) {
            revert InvalidDepositAmount();
        }

        // Transfer collateral tokens from the user to this contract
        IERC20(_collateralToken).safeTransferFrom(user, address(this), amount);

        emit CollateralDeposited(user, amount);
    }


    /**
     * @notice Withdraws collateral from the Vault.
     * @param _collateralToken The address of the collateral token.
     * @param user The address of the user depositing collateral.
     * @param amount Amount of collateral to withdraw.
     */
    function withdrawCollateral(address _collateralToken, address user, uint256 amount) external onlyRole(SIMSTABLE_CONTRACT_ROLE) {
        // Check if the withdraw amount is greater than zero
        if (amount == 0) {
            revert InvalidWithdrawAmount();
        }

        // Transfer collateral tokens to the user from this contract
        IERC20(_collateralToken).safeTransfer(user, amount);

        emit CollateralWithdrawn(user, amount);
    }




    /* ---------- VIEWS ---------- */

    /**
     * @notice Returns the total collateral balance in the Vault.
     * @param _collateralToken The address of the collateral token.
     * @return Total collateral balance.
     */
    function getCollateralBalance(address _collateralToken) external view returns (uint256) {
        return IERC20(_collateralToken).balanceOf(address(this));
    }








}


