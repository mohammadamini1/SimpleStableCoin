// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVault {

    /* ---------- ERRORS ---------- */
    error InvalidCollateralTokenAddress();
    error InvalidSimStableTokenAddress();
    error InvalidDepositAmount();
    error InvalidWithdrawAmount();

    /* ---------- EVENTS ---------- */
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CollateralTokenUpdated(address newCollateralToken);

    /* ---------- EXTERNAL FUNCTIONS ---------- */
    function depositCollateral(address user, uint256 amount) external;
    function withdrawCollateral(address user, uint256 amount) external;

    /* ---------- VIEW FUNCTIONS ---------- */
    function getCollateralBalance() external view returns (uint256);

    /* ---------- ADMIN FUNCTIONS ---------- */

    /**
     * @notice Sets a new collateral token.
     * @param _newCollateralToken New collateral token address.
     */
    function setCollateralToken(address _newCollateralToken) external;
}
