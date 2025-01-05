// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


// Import OpenZeppelin ERC20 implementation and AccessControl
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Import interfaces
import "./interface/IVault.sol";
import "./interface/ISimGov.sol";




// TODO override transfer and transferfrom


contract SimStable is ERC20, AccessControl {
    // Roles
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // SimGov token address
    ISimGov simGov;

    // Vault contract
    IVault public vault;

    // Collateral Ratio (scaled by 1e6, e.g., 750000 for 75%)
    uint256 public collateralRatio;

    // Target Collateral Ratio
    uint256 public targetCollateralRatio;

    // Minimum and Maximum Collateral Ratios
    uint256 public minCollateralRatio;
    uint256 public maxCollateralRatio;

    // Price adjustment coefficient (k, scaled by 1e6)
    uint256 public adjustmentCoefficient;

    // Errors
    error InvalidVaultAddress();
    error InvalidSimGovAddress();

    // Events
    event Minted(address indexed user, uint256 simStableAmount, uint256 collateralAmount, uint256 simGovAmount);
    event Redeemed(address indexed user, uint256 simStableAmount, uint256 collateralAmount, uint256 simGovAmount);
    event Buyback(address indexed user, uint256 simGovAmount, uint256 collateralUsed);
    event ReCollateralized(address indexed user, uint256 collateralAdded, uint256 simGovMinted);
    event CollateralRatioAdjusted(uint256 newCollateralRatio);
    event VaultUpdated(address newVault);
    event SimGovUpdated(address simGov);




    /* ---------- CONSTRUCTOR ---------- */

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());

    }


    /* ---------- CORE FUNCTIONS ---------- */


    function mint(uint256 collateralAmount, uint256 simGovAmount) external {
    }


    function redeem(uint256 simStableAmount) external {
    }


    function buybackSimGov(uint256 simGovAmount) external {
    }


    function reCollateralize(uint256 collateralAdded) external {
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
     * @notice Sets new minimum and maximum collateral ratios.
     * @param _minCollateralRatio New minimum collateral ratio.
     * @param _maxCollateralRatio New maximum collateral ratio.
     */
    function setCollateralRatioBounds(uint256 _minCollateralRatio, uint256 _maxCollateralRatio) external onlyRole(ADMIN_ROLE) {
        require(_minCollateralRatio < _maxCollateralRatio, "Invalid collateral ratio bounds");
        minCollateralRatio = _minCollateralRatio;
        maxCollateralRatio = _maxCollateralRatio;
    }

    /**
     * @notice Sets a new adjustment coefficient.
     * @param _newAdjustmentCoefficient New adjustment coefficient scaled by 1e6.
     */
    function setAdjustmentCoefficient(uint256 _newAdjustmentCoefficient) external onlyRole(ADMIN_ROLE) {
        adjustmentCoefficient = _newAdjustmentCoefficient;
    }



}


