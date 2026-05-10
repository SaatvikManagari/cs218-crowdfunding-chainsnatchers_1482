# CrowdFunding DApp — Project 8 Decentralized Crowdfunding Platform

A decentralized crowdfunding platform built with Solidity and Hardhat, featuring an original contract and a gas-optimized version, with full test coverage (29 tests) and a detailed gas analysis report.

---

## Team Members

| Name | Roll Number |
|------|-------------|
| Managari Saatvik  | 240002035 |
| Malladi Charan | 240008016 |
| Nemani Sandeep | 240002044 |
| Nagalla Abhisri Karthik | 240002041 |
| Prayuktha Lucky Reddy | 240041025 |
| Nitya Sigadapu | 240005048 |

## Implementation 

Website Link: [Crowd Funding Defi Application](https://crowdfundingdefi.netlify.app)

---

## Project Structure

```
CrowdFunding_DApp/
├── contracts/
│   ├── crowdfund_main.sol          ← Original CrowdFund contract
│   └── crowdfund_optimized.sol     ← Gas-optimized CrowdFundOptimized contract
├── test/
│   ├── CrowdFunding.test.js        ← Test suite for original contract (13 tests)
│   └── CrowdFundOptimized.test.js  ← Test suite for optimized contract (16 tests)
├── reports/
│   ├── Gas Optimization report.pdf   ← The optimization report for all the gas functions
│   ├── Gas Report.pdf                ← Gas Report for the solidity code
│   └── Line Coverage.pdf             ← Coverage report for Solidity Code
├── frontend/
│   └── index.html                  ← HTML frontend DApp
├── hardhat.config.ts               ← Hardhat configuration
├── tsconfig.json                   ← TypeScript configuration
├── .solcover.js                    ← Solidity coverage configuration
├── package.json                    ← Project dependencies
└── README.md                       ← This file
```

### Contracts Overview

| Contract | Description |
|---|---|
| `crowdfund_main.sol` | Original implementation with core functions: `createCampaign`, `contribute`, `withdraw`, `refund` |
| `crowdfund_optimized.sol` | Gas-optimized version — removes redundant struct fields and dynamic array, saving ~115,700 gas per `createCampaign()` call |

### Test Files

| Test File | Contract Tested | Tests |
|---|---|---|
| `CrowdFunding.test.js` | `CrowdFund` (original) | 13 tests |
| `CrowdFundOptimized.test.js` | `CrowdFundOptimized` | 16 tests |

---

## Prerequisites

Before setting up the project, ensure you have the following installed:

- **Node.js v20** (v22 works but shows a deprecation warning with Hardhat 2.19.4)
- **npm v7+**
- **Git**
- **WSL / Linux / macOS terminal**
- **MetaMask** browser extension (for interacting with the frontend DApp)
- A code editor such as **VS Code** with the Solidity extension
- MetaMask wallet with sepolia testnet
---

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/CrowdFunding_DApp.git
cd CrowdFunding_DApp
```

### 2. Use the Correct Node Version

If you have `nvm` installed:

```bash
nvm install 20
nvm use 20
node -v   # should print v20.x.x
```

If `nvm` is not installed:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
```

### 3. Install Dependencies

```bash
npm install
```

This installs all packages listed in `package.json`. No additional manual installs are needed.

**If setting up a brand new project from scratch (no `package.json` yet):**

```bash
npm init -y

npm install --save-dev \
  hardhat@2.19.4 \
  @nomicfoundation/hardhat-toolbox@4.0.0 \
  @nomicfoundation/hardhat-network-helpers@1.0.10 \
  @nomicfoundation/hardhat-chai-matchers@2.0.6 \
  @nomicfoundation/hardhat-ethers@3.0.5 \
  @nomicfoundation/hardhat-verify@2.0.5 \
  hardhat-gas-reporter@1.0.10 \
  solidity-coverage@0.8.12 \
  ethers@6.9.0 \
  chai@4.3.10 \
  ts-node@10.9.2 \
  typescript@5.3.3 \
  dotenv@16.3.1

npm install @openzeppelin/contracts@5.0.1
```

---

## Running the Project

### Step 1 — Compile the Contracts

```bash
npx hardhat compile
```

Expected output:
```
Compiled 2 Solidity files successfully (evm target: paris).
```

### Step 2 — Run All Tests

```bash
npx hardhat test
```

Expected output (29 tests total):
```
  CrowdFunding
    Creating a Campaign
      ✔ Should create a campaign successfully
      ✔ Should fail to create a campaign with Negative or zero goal
      ✔ Should fail to create a campaign with past deadline
    Contributing to a Campaign
      ✔ Should allow contributions to an active campaign
      ...

  CrowdFundOptimized
      ✔ Should create a campaign successfully
      ...

  29 passing (Xs)
```

### Step 3 — Run Tests with Gas Report

```bash
REPORT_GAS=true npx hardhat test
```

This prints a gas usage table after the test results showing per-function costs for both contracts. Key output:

```
|  CrowdFund           ·  createCampaign  ·  ~200k gas  |
|  CrowdFundOptimized  ·  createCampaign  ·   ~85k gas  |
```

### Step 4 — Run Coverage Report

```bash
npx hardhat coverage
```
## Gas Optimization

<img width="1385" height="650" alt="Screenshot 2026-05-10 161511" src="https://github.com/user-attachments/assets/ecdbdab3-680e-4ae7-b6d4-eefcff1118e7" />



### Function Optimized: `createCampaign()`

The `createCampaign()` function was identified as the most gas-intensive operation in the contract, performing **9–10 cold `SSTORE` operations** per call at ~22,100 gas each — totalling approximately **~200,000 gas** per transaction.

Three storage writes were found to be entirely avoidable:

### Identified Inefficiencies & Fixes

**OPT-1 — Redundant `campaignid` field in struct**

The `uint campaignid` field was stored inside the campaign struct on every `createCampaign()` call, but campaigns are already indexed by key in `campaign_map`. The field is never read internally.

- **Fix:** Removed `uint campaignid` from the struct entirely.
- **Gas saved:** ~22,100 gas per call (one cold SSTORE eliminated)

**OPT-2 — Dynamic `string metadataCID` in storage**

An IPFS CIDv1 (46–59 bytes) requires 3 cold SSTORE operations to persist — one length slot and two data slots. However, `metadataCID` is already emitted via the `CampaignCreated` event and is permanently accessible off-chain.

- **Fix:** Removed `string metadataCID` from the struct; it remains as a `calldata` parameter passed only into the event.
- **Gas saved:** ~66,300 gas per call (3 cold SSTOREs eliminated)

**OPT-3 — Unnecessary `uint[] campaign_id_list` dynamic array**

Pushing to this array on every `createCampaign()` triggers two storage writes (new element + length update). Since campaign IDs are sequential integers assigned by `campaignCount++`, the full list `{0, 1, 2, ..., campaignCount−1}` can always be reconstructed in memory with zero storage reads.

- **Fix:** Removed the state variable; `getAllCampaignIds()` now builds the array in memory using a loop.
- **Gas saved:** ~27,100 gas per call

### Before vs. After

| Function | Original Gas | Optimized Gas | Saving |
|---|---|---|---|
| `createCampaign()` | ~200,000 | ~85,000 | ~115,700 (~57%) |
| `contribute()` | ~65,000 | ~65,000 | — |
| `withdraw()` | ~35,000 | ~35,000 | — |
| `refund()` | ~35,000 | ~35,000 | — |

The `metadataCID` remains available off-chain via event logs. Campaign ID enumeration is now a pure memory operation that scales to any number of campaigns.

---

## Dependency Versions

| Package | Version | Purpose |
|---|---|---|
| `node` | v20.x.x | JavaScript runtime |
| `hardhat` | 2.19.4 | Ethereum development framework |
| `ethers` | 6.9.0 | Ethereum library (v6 API) |
| `@nomicfoundation/hardhat-toolbox` | 4.0.0 | Bundles all Hardhat plugins |
| `@openzeppelin/contracts` | 5.0.1 | `Ownable`, `ReentrancyGuard` base contracts |
| `chai` | 4.3.10 | Assertion library |
| `hardhat-gas-reporter` | 1.0.10 | Gas usage table per function |
| `solidity-coverage` | 0.8.12 | Statement/branch/line coverage |
| `typescript` | 5.3.3 | TypeScript compiler |
| `dotenv` | 16.3.1 | Environment variable loader |

---

## Cleaning Generated Files

If you need to recompile from scratch, delete only the auto-generated folders — **never touch `contracts/`, `test/`, or config files**:

```bash
rm -rf artifacts cache typechain-types coverage test/coverage
rm -f coverage.json gas-report.txt
```

Then rerun from Step 1.

---

## Files Not Committed to GitHub

The `.gitignore` excludes these auto-generated files:

```
node_modules/
artifacts/
cache/
coverage/
coverage.json
typechain-types/
.env
```

Anyone who clones this repo gets all of the above back by running `npm install` and `npx hardhat compile`.

---

## Known Issues / Limitations

- **Node.js v22 warning:** Hardhat 2.19.4 shows a deprecation warning with Node v22. Use Node v20 for a clean run.
- **Coverage leftover files:** If you see a `window is not defined` error during coverage or tests, run `rm -rf coverage test/coverage coverage.json` and retry.
- **OpenZeppelin import not found:** Run `npm install @openzeppelin/contracts@5.0.1` and recompile.
- **Branch coverage 95.83%:** A small number of implicit Solidity branches (e.g., overflow checks) are not reachable in tests without breaking the EVM — this is expected and not a gap in test design.
- **Frontend is local only:** The `frontend/index.html` DApp must be connected to a locally running Hardhat node or a testnet. It does not connect to mainnet.
- **IPFS is Not Supported by our college network** 
