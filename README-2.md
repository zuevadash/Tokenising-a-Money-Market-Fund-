# Tokenised abrdn Sterling Money Market Fund
### MSc Finance — Blockchain & Digital Assets Coursework
**Sepolia Testnet | Solidity ^0.8.20 | ERC-20**

---

## Overview

This project is a proof-of-concept tokenisation of the **abrdn Sterling Money Market Fund (ISIN: GB00B1BW3H93)** — a UK-domiciled, FCA-regulated Standard Variable NAV (VNAV) Money Market Fund — deployed on the Ethereum Sepolia testnet.

The system is composed of two smart contracts:

| Contract | Symbol | Purpose |
|---|---|---|
| `MockGBP.sol` | mGBP | Fake GBP stablecoin used as the settlement currency |
| `MoneyMarketFund.sol` | aMMF | The tokenised fund — investors hold this to earn interest |

The fund manager (admin) retains full manual control over interest payments, capital deployment, and fund management. This is intentional — the project wraps a traditional centralised fund in an on-chain token, rather than replacing it with a decentralised protocol.

---

## How It Works

```
Investor                    MockGBP                 MoneyMarketFund
   |                           |                           |
   |-- approve(fund, amount) -->|                           |
   |-- subscribe(amount) ----------------------->|          |
   |                           |<-- transferFrom(investor) |
   |                           |                  mint aMMF |
   |<------------------------------------------------ aMMF  |
   |                           |                           |
   |                      [ Admin pays interest ]          |
   |                           |<-- transferFrom(admin)    |
   |                           |         interestPerToken++ |
   |                           |                           |
   |-- claimInterest() --------------------------->|        |
   |<----------------------------------------- mGBP        |
   |                           |                           |
   |-- redeem(amount) -------------------------------->|    |
   |<--------------------------------- mGBP + interest      |
```

**NAV is fixed at £1.00.** 1 aMMF token always equals 1 mGBP on subscription and redemption. All investor return comes from interest distributions made by the admin, benchmarked to the SONIA rate minus a 20bp management fee.

---

## Contracts

### MockGBP.sol

A minimal ERC-20 token that represents tokenised GBP for testing purposes.

- 2 decimal places (£1.00 = 100 units)
- Open `mint()` function — any wallet can issue itself mGBP
- Standard `approve()`, `transfer()`, `transferFrom()` functions
- No imports, no dependencies

**This would be replaced by a regulated FCA-authorised GBP stablecoin in production.**

### MoneyMarketFund.sol

The tokenised fund contract. Issues aMMF tokens 1:1 against mGBP deposits.

- 2 decimal places, matching mGBP
- Interest is distributed using a **checkpoint pattern** — no loops, scales to any number of investors
- Interest accumulates silently in the background and is claimed on demand
- Admin controls all fund operations manually
- No imports, no dependencies

---

## Functions

### Investor Functions

| Function | Description |
|---|---|
| `subscribe(amount)` | Deposit mGBP → receive aMMF tokens 1:1. Approve mGBP first. |
| `redeem(amount)` | Burn aMMF → receive mGBP back 1:1 plus any unclaimed interest |
| `claimInterest()` | Collect earned mGBP interest without touching your aMMF tokens |
| `claimableInterest(address)` | View how much interest an address can claim right now |
| `balanceOf(address)` | View aMMF token balance of any address |

### Admin Functions

| Function | Description |
|---|---|
| `payInterest(amount)` | Distribute mGBP interest pro-rata to all holders. Approve mGBP first. |
| `withdrawMGBP(amount)` | Withdraw mGBP from the fund (simulates deploying capital) |
| `depositMGBP(amount)` | Return mGBP to the fund (simulates capital returning from instruments) |

### MockGBP Functions

| Function | Description |
|---|---|
| `mint(address, amount)` | Mint mGBP to any wallet — open to everyone for testing |
| `approve(spender, amount)` | Authorise the fund to spend your mGBP |
| `transfer(to, amount)` | Send mGBP to another address |
| `balanceOf(address)` | View mGBP balance of any address |

---

## Deployment Guide (Remix IDE)

### Prerequisites
- MetaMask installed with a Sepolia wallet
- Sepolia ETH for gas — get it free at [alchemy.com/faucets/ethereum-sepolia](https://alchemy.com/faucets/ethereum-sepolia)
- Remix IDE open at [remix.ethereum.org](https://remix.ethereum.org)

### Step 1 — Set Up Remix
1. Open Remix and create two new files in the `contracts/` folder
2. Paste `MockGBP.sol` into the first file
3. Paste `MoneyMarketFund.sol` into the second file
4. In the Solidity Compiler tab, set version to `0.8.20` and compile both files

### Step 2 — Connect MetaMask to Sepolia
1. Open MetaMask and switch to **Sepolia Test Network**
2. In Remix, go to **Deploy & Run Transactions**
3. Set Environment to **Injected Provider — MetaMask**
4. Approve the MetaMask connection popup

### Step 3 — Deploy MockGBP
1. Select `MockGBP` in the contract dropdown
2. Click **Deploy** — no constructor arguments needed
3. Confirm in MetaMask
4. **Copy the deployed MockGBP address** from the Deployed Contracts panel

### Step 4 — Mint Test mGBP
1. Expand the MockGBP contract in Deployed Contracts
2. Call `mint` with:
   - `to` → your wallet address
   - `amount` → `1000000` (= £10,000.00)
3. Repeat for any other test wallets

### Step 5 — Deploy MoneyMarketFund
1. Select `MoneyMarketFund` in the contract dropdown
2. Paste the MockGBP address into the `_mGBP` constructor field
3. Click **Deploy** and confirm in MetaMask
4. **Copy the deployed MoneyMarketFund address**

---

## Testing Walkthrough

### Subscribe to the Fund

1. In MockGBP, call `approve`:
   - `spender` → MoneyMarketFund address
   - `amount` → `500000` (= £5,000.00)

2. In MoneyMarketFund, call `subscribe`:
   - `amount` → `500000`

3. Check your aMMF balance: call `balanceOf(yourAddress)` → should return `500000`

### Pay Interest (Admin)

1. In MockGBP (from admin wallet), call `approve`:
   - `spender` → MoneyMarketFund address
   - `amount` → `500` (= £5.00 interest to distribute)

2. In MoneyMarketFund, call `payInterest`:
   - `amount` → `500`

3. Check claimable interest: call `claimableInterest(investorAddress)` → should show share of £5.00

### Claim Interest (Investor)

1. In MoneyMarketFund, call `claimInterest`
2. Check MockGBP balance — it should have increased by the interest amount

### Redeem from the Fund

1. In MoneyMarketFund, call `redeem`:
   - `amount` → `500000` (all tokens)
2. Check MockGBP balance — should be back to original plus any unclaimed interest

---

## Amount Reference

| What you want | Amount to enter |
|---|---|
| £1.00 | `100` |
| £100.00 | `10000` |
| £1,000.00 | `100000` |
| £10,000.00 | `1000000` |

All amounts use 2 decimal places. £1.00 = 100 units, £100.00 = 10000 units.

---

## Interest Distribution — How It Works

The contract uses a **checkpoint pattern** to distribute interest without looping over all investors.

A global counter called `interestPerToken` grows each time the admin calls `payInterest()`. Each investor has a personal `interestDebt` snapshot — the value of `interestPerToken` at the time they last interacted with the contract. The difference between the current global value and their personal snapshot, multiplied by their token balance, gives exactly what they are owed.

```
claimable = (balance × (interestPerToken − interestDebt)) / 1e6
```

This means the admin can pay interest to 1 investor or 10,000 investors at identical gas cost — there is no loop. Investors collect their share whenever they choose by calling `claimInterest()` or `redeem()`.

---

## Project Structure

```
/
├── MockGBP.sol               — GBP stablecoin for testing
├── MoneyMarketFund.sol       — Tokenised MMF contract
└── README.md                 — This file
```

---

## Important Limitations

This is an academic proof of concept. The following simplifications have been made deliberately:

- **MockGBP has no real backing** — anyone can mint unlimited tokens
- **No KYC or AML controls** — any wallet can subscribe
- **SONIA rate is not enforced on-chain** — the admin enters interest amounts manually
- **No professional audit** — do not use on mainnet
- **Single admin key** — a production system would use a multi-signature wallet

---

## Technology Stack

| Component | Choice | Reason |
|---|---|---|
| Blockchain | Ethereum Sepolia | Free testnet with MetaMask support |
| Language | Solidity 0.8.20 | Industry standard for EVM smart contracts |
| Token standard | ERC-20 (manual) | No external imports, maximum simplicity |
| IDE | Remix | Browser-based, no local setup required |
| Settlement currency | MockGBP (mGBP) | Simulates regulated GBP stablecoin |

---

## Author

MSc Finance — Blockchain & Digital Assets  
abrdn Sterling Money Market Fund Tokenisation Project  
Sepolia Testnet — Academic Use Only
