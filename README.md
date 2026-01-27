# Mini-DIT — Experimental Decentralized Identity Tokens Prototype

This repository branch (`mini-dit-prototype`) contains a **lightweight experimental prototype** of **Decentralized Identity Tokens (DIT)** developed as part of early exploration for the **DIT 2026** research direction under Stability Nexus discussions.

⚠️ **Disclaimer**  
This is **not a production-ready implementation**.  
It is a minimal research prototype built to explore design and security trade-offs around decentralized identity tokens.

---

## 🎯 Prototype Goals

This mini-project implements:

- Self-issued Identity NFTs (ERC-721)
- On-chain identity metadata references
- On-chain endorsements between identities
- Revocable endorsements
- Identity compromise / revocation signaling
- Transferable identity tokens
- Foundry-based automated test suite

---

## ❌ Out of Scope

- Zero-knowledge proofs  
- Formal claim verification schemas  
- Governance or reputation scoring  
- Sybil-resistance mechanisms  
- Production security hardening  

---

## 🏗️ Tech Stack

### Smart Contracts
- Solidity ^0.8.20  
- OpenZeppelin ERC-721  
- Foundry (Forge, Cast, Anvil)

### Testing
- Foundry Test Framework

---

## 📁 Project Structure

src/
└── MiniDIT.sol # Identity Token smart contract

test/
└── MiniDIT.t.sol # Foundry test suite

foundry.toml # Foundry configuration


---

## ⚙️ Prerequisites

- Node.js 18+  
- Foundry installed  
  [Foundry Installation Guide](https://book.getfoundry.sh/getting-started/installation)

---

## 🚀 Installation

Clone repository and switch to prototype branch:

```bash
git clone https://github.com/<your-username>/IdentityTokens-EVM-Contracts.git
cd IdentityTokens-EVM-Contracts
git checkout mini-dit-prototype
Install dependencies:

forge install
🧪 Run Tests
forge test
Expected output:

All MiniDIT tests passing
🔍 Smart Contract Overview
Mint Identity NFT
mintIdentity(string metadataURI)
Endorse Another Identity
endorse(fromTokenId, toTokenId, tag)
Revoke Endorsement
revokeEndorsement(toTokenId, index)
Mark Identity as Compromised
markCompromised(tokenId)
🧠 Research Context
This prototype is based on ongoing discussions around:

DIT (Decentralized Identity Tokens)

TNT (Trust Network Tokens)

VouchMe-style identity endorsement flows

Under the Stability Nexus / The Stable Order research direction.


---

# ✅ After pasting

Run:

```bash
git add README.md
git commit -m "Fix README markdown formatting and links"
git push origin mini-dit-prototype
