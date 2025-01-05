// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISimGov {

    /* ---------- ERRORS ---------- */
    error InvalidSimStableTokenAddress();

    /* ---------- FUNCTIONS ---------- */
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;

}
