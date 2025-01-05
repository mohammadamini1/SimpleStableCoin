// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVault {

    /* ---------- ERRORS ---------- */
    error InvalidSimStableTokenAddress();
    error InvalidDepositAmount();
    error InvalidWithdrawAmount();

    /* ---------- EVENTS ---------- */
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);

    /* ---------- FUNCTIONS ---------- */
    function depositCollateral(address _collateralToken, address user, uint256 amount) external;
    function withdrawCollateral(address _collateralToken, address user, uint256 amount) external;

    /* ---------- VIEW FUNCTIONS ---------- */
    function getCollateralBalance(address _collateralToken) external view returns (uint256);

}
