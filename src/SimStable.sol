// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// Import OpenZeppelin ERC20 implementation and AccessControl
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


// Interfaces
interface IVault {
    function depositCollateral(address user, uint256 amount) external;
    function withdrawCollateral(address user, uint256 amount) external;
    function getCollateralBalance() external view returns (uint256);
}

contract SimStable is ERC20, AccessControl {
    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());


    }

    // TODO override transfer and transferfrom

    function mint(uint256 collateralAmount, uint256 simGovAmount) external {
    }


    function redeem(uint256 simStableAmount) external {
    }


    function buybackSimGov(uint256 simGovAmount) external {
    }


    function reCollateralize(uint256 collateralAdded) external {
    }


}


