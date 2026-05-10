# CrowdFunding DApp — Smart Contract Project

A decentralized crowdfunding platform built with Solidity and Hardhat, featuring
an original contract and a gas-optimized version with full test coverage and gas
analysis reports.

---

## Project Structure

```
CrowdFunding_DApp/
├── contracts/
│   ├── crowdfund_main.sol          ← Original CrowdFund contract
│   └── crowdfund_optimized.sol     ← Gas-optimized CrowdFundOptimized contract
├── test/
│   ├── CrowdFunding.test.js        ← Test suite for original contract
│   └── CrowdFundOptimized.test.js  ← Test suite for optimized contract
├── frontend/
│   └── index.html                  ← HTML frontend DApp
├── hardhat.config.ts               ← Hardhat configuration
├── tsconfig.json                   ← TypeScript configuration
├── .solcover.js                    ← Solidity coverage configuration
├── package.json                    ← Project dependencies
├── package-lock.json               ← Locked dependency versions
├── .gitignore                      ← Git ignored files
└── README.md                       ← This file
```

### What each contract does

| Contract | Description |
|---|---|
| `crowdfund_main.sol` | Original implementation of the CrowdFund contract with all core functions: `createCampaign`, `contribute`, `withdraw`, `refund` |
| `crowdfund_optimized.sol` | Gas-optimized version — removes redundant `campaignid` struct field, `string metadataCID` from storage, and `uint[] campaign_id_list` dynamic array, saving ~115,700 gas per `createCampaign()` call |

### What each test file does

| Test File | Contract Tested | No. of Tests |
|---|---|---|
| `CrowdFunding.test.js` | `CrowdFund` (original) | 13 tests |
| `CrowdFundOptimized.test.js` | `CrowdFundOptimized` | 16 tests |

---

## Software Versions

These are the exact versions installed and verified to work together:

| Package | Version | Purpose |
|---|---|---|
| `node` | v20.x.x (recommended) | JavaScript runtime |
| `hardhat` | 2.19.4 | Ethereum development framework |
| `ethers` | 6.9.0 | Ethereum library (v6 API) |
| `@nomicfoundation/hardhat-toolbox` | 4.0.0 | Bundles all Hardhat plugins |
| `@nomicfoundation/hardhat-ethers` | 3.0.5 | Ethers.js integration |
| `@nomicfoundation/hardhat-chai-matchers` | 2.0.6 | Smart contract test assertions |
| `@nomicfoundation/hardhat-network-helpers` | 1.0.10 | `time`, `loadFixture` test helpers |
| `@nomicfoundation/hardhat-verify` | 2.0.5 | Contract verification |
| `hardhat-gas-reporter` | 1.0.10 | Gas usage table per function |
| `solidity-coverage` | 0.8.12 | Statement/branch/line coverage |
| `@openzeppelin/contracts` | 5.0.1 | `Ownable`, `ReentrancyGuard` base contracts |
| `chai` | 4.3.10 | Assertion library |
| `ts-node` | 10.9.2 | TypeScript execution for Hardhat config |
| `typescript` | 5.3.3 | TypeScript compiler |
| `dotenv` | 16.3.1 | Environment variable loader |

---

## Prerequisites

- **Node.js v20** (v22 works but shows a warning with Hardhat 2.19.4)
- **npm v7+**
- **WSL / Linux / macOS terminal**
- **Git**

---

## Setup From Scratch

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/CrowdFunding_DApp.git
cd CrowdFunding_DApp
```

### 2. Use the correct Node version

```bash
# if you have nvm installed
nvm install 20
nvm use 20
node -v   # should print v20.x.x
```

If nvm is not installed:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
```

### 3. Install all dependencies

```bash
npm install
```

This installs everything listed in `package.json` — no manual installs needed.

If setting up a **brand new project** from scratch (no `package.json` yet):
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

### Step 1 — Compile the contracts

```bash
npx hardhat compile
```

Expected output:
```
Compiled 2 Solidity files successfully (evm target: paris).
```

This generates the `artifacts/`, `cache/`, and `typechain-types/` folders automatically.

---

### Step 2 — Run all tests

```bash
npx hardhat test
```

Expected output:
```
  CrowdFunding
    Creating a Campaign
      ✔ Should create a campaign successfully
      ✔ Should fail to create a campaign with Negative or zero goal
      ✔ Should fail to create a campaign with past deadline
    Contributing to a Campaign
      ✔ Should allow contributions to an active campaign
      ✔ Should fail to contribute when campaign is not Active
      ✔ Should fail to contribute after the campaign deadline
      ✔ Should fail to contribute with zero amount
    Withdrawing Funds
      ✔ Should allow the campaign creator to withdraw funds
      ✔ Should fail to withdraw funds if the goal is not met
      ✔ Should fail to withdraw funds if deadline is in the future
      ✔ Should fail to withdraw funds if caller is not campaign creator
      ✔ Should fail on double withdrawal attempt
    Refunding Contributors
      ✔ Should refund contributor correctly when campaign fails
      ✔ Should fail to refund contributors if the campaign is successful
      ✔ Should fail to refund if caller is not a contributor

  CrowdFundOptimized
    Creating a Campaign
      ✔ Should create a campaign successfully
      ... (16 tests total)

  29 passing (Xs)
```

---

### Step 3 — Run tests with Gas Report

```bash
REPORT_GAS=true npx hardhat test
```

Expected output (gas table appears after test results):
```
·--------------------------------|---------------------------|--------------|-----------------------------·
|      Solidity and Network      ·  Methods                  ·              ·       Deployments           |
·································|···························|··············|·····························|
|  Contract                      ·  Method                   ·  Min  · Max  ·  Avg  ·  # calls  ·  usd   |
·································|···························|··············|·····························|
|  CrowdFund                     ·  createCampaign           ·   -   ·  -   ·  ~200k·     X     ·   -    |
|  CrowdFund                     ·  contribute               ·   -   ·  -   ·  ~65k ·     X     ·   -    |
|  CrowdFund                     ·  withdraw                 ·   -   ·  -   ·  ~35k ·     X     ·   -    |
|  CrowdFund                     ·  refund                   ·   -   ·  -   ·  ~35k ·     X     ·   -    |
·································|···························|··············|·····························|
|  CrowdFundOptimized            ·  createCampaign           ·   -   ·  -   ·  ~85k ·     X     ·   -    |
|  CrowdFundOptimized            ·  contribute               ·   -   ·  -   ·  ~65k ·     X     ·   -    |
|  CrowdFundOptimized            ·  withdraw                 ·   -   ·  -   ·  ~35k ·     X     ·   -    |
|  CrowdFundOptimized            ·  refund                   ·   -   ·  -   ·  ~35k ·     X     ·   -    |
·--------------------------------|---------------------------|--------------|-----------------------------·
```

This clearly shows `createCampaign()` dropping from ~200k to ~85k gas after optimization.

---

### Step 4 — Run Coverage Report

```bash
npx hardhat coverage
```

Expected output:
```
--------------------------|----------|----------|----------|----------|----------------|
File                      |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
--------------------------|----------|----------|----------|----------|----------------|
 contracts/               |          |          |          |          |                |
  crowdfund_main.sol      |      100 |    95.83 |      100 |      100 |                |
  crowdfund_optimized.sol |      100 |    95.83 |      100 |      100 |                |
--------------------------|----------|----------|----------|----------|----------------|
All files                 |      100 |    95.83 |      100 |      100 |                |
--------------------------|----------|----------|----------|----------|----------------|
```

The full visual HTML coverage report is generated at `coverage/index.html`.

Open it in your Windows browser from WSL:
```
\\wsl$\Ubuntu\home\charan\CrowdFunding_DApp\coverage\index.html
```

---

## Cleaning Generated Files (Fresh Restart)

If you need to recompile everything from scratch, delete only the auto-generated
folders — **never touch contracts/, test/, or config files**:

```bash
rm -rf artifacts
rm -rf cache
rm -rf typechain-types
rm -rf coverage
rm -rf test/coverage
rm -f coverage.json
rm -f gas-report.txt
```

Then rerun from Step 1.

---

## Files NOT committed to GitHub

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

Anyone who clones this repo gets all of the above back by just running
`npm install` and `npx hardhat compile`.

---

## Gas Optimization Summary

The key finding of this project: `createCampaign()` in the original contract
performs 9-10 cold `SSTORE` operations. Three were entirely avoidable:

| Optimization | What was removed | Gas saved |
|---|---|---|
| OPT-1 | `uint campaignid` field from struct | ~22,100 gas |
| OPT-2 | `string metadataCID` from struct storage | ~66,300 gas |
| OPT-3 | `uint[] campaign_id_list` dynamic array push | ~27,100 gas |
| **Total** | | **~115,700 gas per call (~57% reduction)** |

The `metadataCID` is still accessible off-chain via the `CampaignCreated` event log.
The campaign ID list is recomputed in memory from `campaignCount` with zero storage reads.

---

## Troubleshooting

**`window is not defined` error during coverage:**
```bash
rm -rf coverage test/coverage coverage.json
npx hardhat coverage
```

**`window is not defined` error during test:**
```bash
# leftover coverage files ended up in test/ folder
rm -rf test/coverage
npx hardhat test
```

**OpenZeppelin import not found:**
```bash
npm install @openzeppelin/contracts@5.0.1
npx hardhat compile
```

**Node.js version warning:**
```bash
nvm install 20 && nvm use 20
```
