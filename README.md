Algorithmic Stablecoin Prototype Documentation
==============================================

<!-- Table of Contents
-----------------

1.  [Introduction](#introduction)
2.  [System Overview](#system-overview)
3.  [Core Components](#core-components)
    -   [SimStable (Stable Token)](#simstable-stable-token)
    -   [SimGov (Governance Token)](#simgov-governance-token)
    -   [Vault](#vault)
4.  [Implementation Details](#implementation-details)
    -   [Smart Contracts](#smart-contracts)
        -   [Vault.sol](#vaultsol)
        -   [ISimGov.sol](#isimgovsol)
        -   [IVault.sol](#ivaultsol)
        -   [SimStable.sol](#simstablesol)
        -   [SimGov.sol](#simgovsol)
    -   [Price Feed](#price-feed)
    -   [Testing](#testing)
    -   [Deployment](#deployment)
5.  [Getting Started](#getting-started)
    -   [Prerequisites](#prerequisites)
    -   [Installation](#installation)
    -   [Running Tests](#running-tests)
    -   [Deployment Instructions](#deployment-instructions)
6.  [Usage](#usage)
7.  [Contributing](#contributing)
8.  [License](#license)
9.  [Appendix](#appendix)
10. [Contact](#contact) -->





* * * * *

Introduction
------------

The **Algorithmic Stablecoin Prototype** is a simplified model of fractional-algorithmic stablecoins. This prototype features core functionalities such as minting, redeeming, buybacks, re-collateralization, and dynamic collateral adjustments based on the stable token's price and governance token supply.

* * * * *

System Overview
---------------

The system comprises three primary components:

1.  **Stable Token (SimStable):** A stablecoin pegged to 1 USD, backed by collateral and governed by dynamic mechanisms.
2.  **Governance Token (SimGov):** A governance token used to control and regulate the system's parameters.
3.  **Central Vault:** A smart contract holding the collateral backing the stable token.

These components interact to maintain the stability of SimStable through mechanisms like minting new tokens, redeeming existing ones, executing buybacks, and adjusting collateral ratios dynamically based on market conditions.

* * * * *

Core Components
---------------

### SimStable (Stable Token)

SimStable is an ERC20-compliant stablecoin designed to maintain a 1 USD peg. It utilizes a combination of collateral and SimGov tokens to back its value. Key functionalities include:

-   **Minting:** Users can mint SimStable by providing collateral and burning SimGov tokens.
-   **Redeeming:** Users can redeem SimStable for collateral and receive newly minted SimGov tokens.
-   **Buyback:** The system can buy back SimGov tokens using surplus collateral when the collateral ratio exceeds the target.
-   **Re-Collateralization:** Users can add more collateral to the system in exchange for SimGov tokens when the collateral ratio falls below a predefined threshold.
-   **Dynamic Collateral Adjustments:** The collateral ratio adjusts based on the market price of SimStable and SimGov tokens to maintain peg stability.

### SimGov (Governance Token)

SimGov is an ERC20-compliant governance token that plays a critical role in regulating the system's parameters. It is used in minting and redeeming SimStable tokens and in governance mechanisms that adjust system parameters like collateral ratios.

### Vault

The Vault is a smart contract responsible for holding and managing the collateral backing SimStable. It ensures secure storage and handles the deposit and withdrawal of collateral tokens.

* * * * *

Implementation Details
----------------------

### Smart Contracts

The project includes the following smart contracts:



#### SimStable.sol

**Location:** `./src/SimStable.sol`

**Description:** The core stablecoin contract implementing minting, redeeming, buybacks, re-collateralization, and dynamic collateral ratio adjustments.

**Key Features:**

-   **Roles:** `ADMIN_ROLE`.
-   **Collateral Ratio Management:** Dynamically adjusts based on price deviations to maintain peg stability.
-   **Minting & Redeeming:** Users can mint SimStable by providing collateral and burning SimGov, or redeem SimStable for collateral and minting SimGov.
-   **Buyback Mechanism:** Buys back SimGov tokens when surplus collateral is available.
-   **Re-Collateralization:** Allows users to add collateral in exchange for SimGov when collateral ratios are low.
-   **Price Feeds:** Utilizes Uniswap V2 pools to fetch current prices for SimStable and SimGov.
-   **Events:** Emits events for actions like minting, redeeming, buybacks, and collateral ratio adjustments.

**Key Functions:**

-   `mint(uint256 _collateralAmount, uint256 _minSimStableAmount)`
-   `redeem(uint256 _simStableAmount, uint256 _minCollateralAmount, uint256 _minSimGovAmount)`
-   `buyback(uint256 simGovAmount)`
-   `reCollateralize(uint256 _collateralAmount, uint256 _minSimGovAmount)`
-   `adjustCollateralRatio()`
-   `getTokenPrice(address tokenA, address tokenB)`
-   `getSimGovPrice()`
-   `getSimStablePrice()`


#### SimGov.sol

**Location:** `./src/SimGov.sol`

**Description:** The governance token contract, allowing minting and burning by authorized contracts (primarily SimStable).

**Key Features:**

-   **Roles:** `MINTER_ROLE`, `DEFAULT_ADMIN_ROLE`.
-   **Functions:**
    -   `mint(address to, uint256 amount)`: Mints new SimGov tokens.
    -   `burn(address from, uint256 amount)`: Burns existing SimGov tokens.


#### Vault.sol

**Location:** `./src/Vault.sol`

**Description:** The Vault contract manages collateral deposits and withdrawals by authorized contracts (primarily SimStable).

**Key Features:**

-   **Roles:** `SIMSTABLE_CONTRACT_ROLE`, `ADMIN_ROLE`.
-   **Functions:**
    -   `depositCollateral(address _collateralToken, address user, uint256 amount)`: Deposit collateral on behalf of the user.
    -   `withdrawCollateral(address _collateralToken, address user, uint256 amount)`: Withdraw collateral on behalf of the user.
    -   `getCollateralBalance(address _collateralToken)`: Returns the total collateral balance for a given token.



### Price Feed

The system utilizes Uniswap V2 pools as decentralized price oracles to fetch real-time price data for SimStable and SimGov tokens. The price calculation involves the following steps:

1.  **Collateral-Token Pair:**
    The system first fetches the price of the system token (SimStable or SimGov) in terms of the collateral token (e.g., WETH) using the respective Uniswap V2 pool.

2.  **Collateral-Collateral Pair:**
    The system then fetches the price of the collateral token (e.g., WETH) against a stable reference asset (e.g., DAI) using another Uniswap V2 pool.

3.  **Market Price Calculation:**
    By dividing the price obtained from the Collateral-Collateral pair by the price from the Collateral-Token pair, the system calculates the market price of the system tokens in USD terms.

    **Example:**

    -   **SimStable/WETH Pool:** Determines the price of SimStable in WETH.
    -   **WETH/DAI Pool:** Determines the price of WETH in DAI.
    -   **Market Price of SimStable:**
    - $Price of SimStable in USD=\dfrac{Price of WETH in USD}{Price of SimStable in WETH}$

This approach ensures that the system maintains accurate and up-to-date price feeds necessary for calculating collateral ratios and ensuring the stability of the SimStable token.


### Testing

Performed fork testing against the Ethereum mainnet using the latest state data from Uniswap V2 pools. This approach allows the simulation of real-world interactions and price feeds, ensuring that the smart contracts behave correctly with up-to-date market conditions. Unit tests are written using **Foundry** framework. These tests cover all functionalities for users and admin.

To execute the test suite, run the following command in the root directory
```javascript
forge test
```


### Deployment

Deployment scripts is provided in script/Deploy.s.sol and below is a summary of the deployment process:

1.  **Deploy SimStable:**
    Begin by deploying the `SimStable` contract

2.  **Deploy SimGov and Vault:**
    -   **SimGov Deployment:** Deploy the `SimGov` contract. the address of the deployed `SimStable` contract during its deployment used establish the necessary permissions.

    -   **Vault Deployment:** Deploy the `Vault` contract. the address of the deployed `SimStable` contract during its deployment used establish the necessary permissions.

3.  **Set SimGov and Vault Addresses in SimStable:**
    After deploying both `SimGov` and `Vault`, update the `SimStable` contract with their respective addresses. This linkage is crucial for enabling `SimStable` to interact with `SimGov` and manage collateral through the `Vault`.


4.  **Transfer Required Collateral:**
    Transfer the necessary collateral tokens (e.g., WETH) to the `SimStable` contract. This collateral is essential for creating pools on uniswap.

5.  **Initialize Uniswap V2 Liquidity Pools:**
    With all contracts deployed and configured, proceed to create the liquidity pools on Uniswap V2. This involves calling the `createUniswapV2SimStablePool` and `createUniswapV2SimGovPool` functions within the `SimStable` contract. These functions set up the necessary pools for `SimStable` and `SimGov` against the collateral (e.g., WETH).


To execute the deploy script, run the following command in the root directory
```javascript
source .env
forge script --chain holesky script/Deploy.s.sol:DeployScript --rpc-url $HOLESKY_RPC_URL --broadcast -vvvv
```






* * * * *

Getting Started
---------------

### Prerequisites

-   **Foundry**

### Installation

1.  **Clone the Repository:**
    ```
    git clone https://github.com/mohammadamini1/simplestablecoin.git
    cd simplestablecoin
    ```


2.  **Configure Environment Variables:**
    Create a `.env` file in the root directory and add necessary variables like `PRIVATE_KEY`.


### Running Tests
```
forge test
```


* * * * *


License
-------

This project is licensed under the MIT License.

* * * * *

Appendix
--------

### Contract Roles and Permissions

-   **Admin Role:**
    -   Granted to the deployer.
    -   Can set addresses for Vault, SimGov, and update system parameters.
    -   Can create Uniswap V2 pools and add liquidity.

-   **Minter Role (SimGov and Vault):**
    -   Granted to the SimStable contract.
    -   Allows SimStable to mint and burn SimGov tokens as needed.
    -   Allows SimStable to deposit and withdraw on behalf of user as needed.





### Future Work

There are several enhancements and features that can be implemented to improve its robustness, security, and usability. Below is a list of proposed future work:

-   **Implement Time-Weighted Average Price (TWAP) Feed:**
    Replace the current spot price feed mechanism with a TWAP-based system to mitigate the risk of price manipulation and provide more reliable price data.

-   **Make Contracts Pausable:**
    Integrate the `Pausable` feature from OpenZeppelin to allow administrators to pause contract functionalities in case of emergencies or detected vulnerabilities.

-   **Add Simulation Functions:**
    Develop simulation functions to calculate potential outcomes, such as the amount of SimStable tokens minted or redeemed during transactions.

-   **Enhance Governance Mechanisms:**
    Introduce more comprehensive governance features, such as voting systems for protocol parameter adjustments.

-   **Integrate Additional Collateral Types:**
    Expand the system to support multiple types of collateral beyond WETH.

-   **Expand Testing Coverage:**
    Implement fuzz testing, stateful testing, and invariant testing

-   **Explore Layer 2 Scaling Solutions:**
    Integrate Layer 2 solutions such as Optimistic Rollups or zk-Rollups to improve transaction throughput and reduce costs.




