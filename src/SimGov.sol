// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// Import OpenZeppelin ERC20 implementation and AccessControl
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract SimGov is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");


    // Errors
    error InvalidSimStableTokenAddress();




    /* ---------- CONSTRUCTOR ---------- */

    constructor(address _simStableAddress, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        // Check for the zero address.
        if (_simStableAddress == address(0)) {
            revert InvalidSimStableTokenAddress();
        }

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _simStableAddress);
    }

    /**
     * @notice Mints SimGov tokens.
     * @param to Address to receive the minted tokens.
     * @param amount Number of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Burns SimGov tokens.
     * @param from Address from which tokens will be burned.
     * @param amount Number of tokens to burn.
     */
    function burn(address from, uint256 amount) external onlyRole(MINTER_ROLE) {
        _burn(from, amount);
    }


}



