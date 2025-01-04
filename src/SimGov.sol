// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// Import OpenZeppelin ERC20 implementation and AccessControl
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract SimGov is ERC20, AccessControl {

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
    }


}



