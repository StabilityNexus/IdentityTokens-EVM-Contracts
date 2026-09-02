<!-- Don't delete it -->
<div name="readme-top"></div>

<!-- Organization Logo -->
<div align="center" style="display: flex; align-items: center; justify-content: center; gap: 16px;">
  <img alt="Stability Nexus" src="public/stability.svg" width="175">
  <img src="public/logo.svg" width="175" />
</div>

&nbsp;

<!-- Organization Name -->
<div align="center">

[![Static Badge](https://img.shields.io/badge/IdentityTokens_EVM-Contracts-228B22?style=for-the-badge&label=Stability%20Nexus&labelColor=FFC517)](https://identitytokens.stability.nexus/)

<!-- Correct deployed url to be added -->

</div>

<!-- Organization/Project Social Handles -->
<p align="center">
<!-- Telegram -->
<a href="https://t.me/StabilityNexus">
<img src="https://img.shields.io/badge/Telegram-black?style=flat&logo=telegram&logoColor=white&logoSize=auto&color=24A1DE" alt="Telegram Badge"/></a>
&nbsp;&nbsp;
<!-- X (formerly Twitter) -->
<a href="https://x.com/StabilityNexus">
<img src="https://img.shields.io/twitter/follow/StabilityNexus" alt="X (formerly Twitter) Badge"/></a>
&nbsp;&nbsp;
<!-- Discord -->
<a href="https://discord.gg/YzDKeEfWtS">
<img src="https://img.shields.io/discord/995968619034984528?style=flat&logo=discord&logoColor=white&logoSize=auto&label=Discord&labelColor=5865F2&color=57F287" alt="Discord Badge"/></a>
&nbsp;&nbsp;
<!-- Blogs -->
<a href="https://viewpoints.stability.nexus/">
  <img src="https://img.shields.io/badge/Stable_Viewpoints-Articles-2ea44f?style=flat&labelColor=facc15" alt="Stable Viewpoints"></a>
&nbsp;&nbsp;
<!-- LinkedIn -->
<a href="https://linkedin.com/company/stability-nexus">
  <img src="https://img.shields.io/badge/LinkedIn-black?style=flat&logo=LinkedIn&logoColor=white&logoSize=auto&color=0A66C2" alt="LinkedIn Badge"></a>
&nbsp;&nbsp;
<!-- Youtube -->
<a href="https://www.youtube.com/@StabilityNexus">
  <img src="https://img.shields.io/youtube/channel/subscribers/UCZOG4YhFQdlGaLugr_e5BKw?style=flat&logo=youtube&logoColor=white&logoSize=auto&labelColor=FF0000&color=FF0000" alt="Youtube Badge"></a>
</p>

---

<div align="center">
  <h1> IdentityTokens-EVM-Contracts</h1>
  <p>
    IdentityTokens-EVM-Contracts is a decentralized identity protocol built on EVM-compatible blockchains that enables individuals to self-issue ERC-721 NFT-based identity tokens with optional metadata such as name, social links, age, nationality, and residence. Users maintain full control over their digital identities and can attest other identity tokens on-chain, creating a transparent and verifiable web of trust. The system ensures efficient on-chain mappings between tokens, metadata, and attestation relationships, supporting multiple identity tokens per user while enabling scalable and reliable identity verification.
  </p>
</div>

---

## 🛠️ Tech Stack

### ⛓️ Blockchain (Smart Contracts)

- **Language:** Solidity ^0.8.24
- **Smart Contracts:** Custom EVM-based contracts implementing protocol logic, token standards, and access control
- **Development Framework:** Foundry
    - **Testing:** Forge Standard Library (`forge-std`)
    - **Deployment:** Forge Scripts (Anvil, Sepolia)
- **Libraries:**
    - OpenZeppelin Contracts v5.5.0
- **Static Analysis & Linting:**
    - Slither (security analysis)
    - Solhint (linting & style enforcement)
    - Prettier Plugin Solidity (code formatting)

### 🌐 Frontend & Web3 Integration

- **Wagmi:** React hooks for Ethereum interactions (wallet connection, contract reads/writes, event tracking)
- **Ethers.js:** Ethereum library for interacting with providers and smart contracts
- **Wallet Integration:** MetaMask, WalletConnect (via Wagmi connectors)

### 🚀 CI/CD & DevOps

- **GitHub Actions:** Automated lint, build (Forge), and test workflows
- **Pre-commit Hooks:** Code quality enforcement before commits
- **Package Manager:** npm

---

## 📜 Deployed Smart Contracts (Sepolia Testnet)

The smart contracts are currently deployed on the Ethereum **Sepolia Testnet**:

| Smart Contract     | Contract Address                             | Sepolia Etherscan Link                                                                               |
| ------------------ | -------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **IdentitySystem** | `0xe886929760A5B8E47Cb42679512C920Fd1b14431` | [View on Etherscan](https://sepolia.etherscan.io/address/0xe886929760A5B8E47Cb42679512C920Fd1b14431) |
| **ProfileSystem**  | `0xDf36b4Cc1fB9d65CB371e0ee88EB9e4b4A30E423` | [View on Etherscan](https://sepolia.etherscan.io/address/0xDf36b4Cc1fB9d65CB371e0ee88EB9e4b4A30E423) |

---

## 🔄 Workflow

To understand the development process, contribution flow, and project structure, please refer to the detailed workflow guide:

👉 [View Workflow](docs/WORKFLOWS.md)

---

## 🚀 Getting Started

### Prerequisites

To build, test, and deploy the smart contracts, ensure the following tools are installed:

- **Node.js (v18 or higher)** – Required for managing dependencies and running formatting/linting tools.
- **Foundry** – Primary development framework for compiling, testing, and deploying smart contracts.
- **Git** – Required for cloning the repository and managing submodules.
- **Web3 Wallet (e.g., MetaMask)** – For interacting with deployed contracts on local or live networks.

## Installation

### 1. Clone the Repository

Clone the project and navigate into the root directory:

```bash
git clone https://github.com/StabilityNexus/IdentityTokens-EVM-Contracts.git
cd IdentityTokens-EVM-Contracts
```

### 2. Install Dependencies

The project requires both Node.js packages for styling/linting and Foundry for smart contract logic:

Install Node.js Tools (Prettier, Solhint):

```Bash
npm install
```

```bash
#### Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

```bash
# Install OpenZeppelin for Foundry
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
```

### 3. Build and Test

Ensure everything is configured correctly by compiling the contracts and running the automated test suite:

#### Compile Contracts

```bash
forge build
```

#### Run Tests

```bash
forge test
```

#### Run Tests with Gas Report

```bash
forge test --gas-report
```

#### Run Tests with Verbose Output

```bash
forge test -vvvv
```

#### Check Contract Sizes

```bash
forge build --sizes
```

#### Clean Build Artifacts

```bash
forge clean
```

## We appreciate your feedback and contributions!

<p align="center">
  © 2026 The Stable Order.
</p>
