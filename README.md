# CARBONCHAIN - Decentralized Carbon Credit Trading

A blockchain-based **carbon credit marketplace** designed to bring transparency, security, and efficiency to the growing voluntary carbon market.
Inspired by the market’s growth from **$4.04B in 2024** to a projected **$23.99B by 2030**, this contract addresses fraud and opacity in traditional systems by enabling verifiable carbon credit issuance, trading, and retirement.

---

## Features

* **Carbon Projects Registry**: Verified offset projects can register and issue carbon credits.
* **Verifier System**: Third-party auditors stake tokens, verify projects, and maintain reputation scores.
* **Marketplace Trading**: Companies and individuals can buy and sell carbon credits through on-chain orders.
* **Credit Balances**: Transparent ownership tracking per user and per project.
* **Carbon Retirement**: Credits can be permanently retired to offset emissions, with certificates and reasons recorded.
* **Transaction History**: Immutable on-chain log of issuances, trades, and retirements.
* **Platform Fees**: Trading and retirement fees fund platform sustainability.
* **Admin Controls**: Emergency trading toggle and platform fee withdrawal.

---

## Data Structures

* **carbon-projects**: Registry of projects (developer, type, verification standard, credits, methodology, vintage year).
* **credit-balances**: User balances of credits per project.
* **retired-credits**: Records of permanently retired credits (with certificates).
* **authorized-verifiers**: Verified auditors with stake and reputation.
* **trading-orders**: Open marketplace orders for carbon credit trading.
* **transaction-history**: Record of all credit-related transactions.

---

## Key Constants

* **Project Types**: Forest, Renewable, Methane, Soil, Direct Air Capture.
* **Standards**: VCS, Gold, CDM, Plan Vivo.
* **Minimum Stakes**:

  * Project: **5 STX**
  * Verifier: **10 STX**
* **Fees**:

  * Trading Fee: **0.25%**
  * Retirement Fee: **0.1 STX**

---

## Core Functions

### Verifier Management

* `register-verifier(organization, certification-standard, stake-amount)`

### Project Management

* `register-project(project-name, location, project-type, verification-standard, methodology, vintage-year, stake-amount)`
* `verify-project(project-id)`
* `issue-credits(project-id, amount, price-per-credit)`

### Trading System

* `create-sell-order(project-id, amount, price-per-credit, duration-blocks)`
* `buy-credits(order-id, amount)`
* `cancel-order(order-id)`

### Carbon Retirement

* `retire-credits(project-id, amount, retirement-reason, certificate-hash)`

### Read-Only Views

* `get-project-info(project-id)`
* `get-credit-balance(user, project-id)`
* `get-order-info(order-id)`
* `get-retirement-info(retirement-id)`
* `get-verifier-info(verifier)`
* `get-platform-stats()`
* `get-transaction-info(tx-id)`
* `calculate-co2-offset(retirement-id)`

### Administration

* `toggle-trading()` – enable/disable trading.
* `withdraw-fees(amount)` – withdraw accumulated platform fees.

---

## Platform Stats

* Tracks **total projects**, **credits issued**, **credits retired**, **active orders**, **platform fees**, and **trading status**.

---

## Security & Governance

* **Error Codes** for invalid actions, unauthorized calls, insufficient credits, duplicate entries, etc.
* **Stake Requirements** prevent spam and ensure commitment.
* **Verifier Reputation** incentivizes honest verification.
* **Admin Safeguards** allow halting of trading in emergencies.

---

## Use Cases

* Transparent carbon credit issuance and trading.
* Reliable verification of projects and auditors.
* Permanent retirement of credits for corporate or personal emissions offsets.
* On-chain traceability of all carbon market activity.

---

## License

Open-source and adaptable for sustainable blockchain-based carbon market solutions.
