# 📘 WORKFLOWS

This document provides an overview of all major workflows in the system. Each section includes a brief explanation and a visual diagram to help you quickly understand how different parts of the platform interact.

---

## 🔗 Connect Wallet

This is the entry point for users. By connecting a wallet, users can securely interact with the platform, sign transactions, and access features like token creation and attestations.

<p align="center">
  <img src="../public/workflows/connect.png" width="600"/>
</p>

---

## 🪙 Create DIT Token (Using Platform)

Users can create a DIT token through a simple and guided UI. The platform handles contract interaction, metadata setup, and transaction flow, making it beginner-friendly.

<p align="center">
  <img src="../public/workflows/create-token.png" width="600"/>
</p>

---

## ⚙️ Create DIT Token (Without Platform)

This workflow is for advanced users who prefer direct interaction with smart contracts. It involves manually calling contract functions and handling parameters without the platform UI.

<p align="center">
  <img src="../public/workflows/create-token-N.png" width="600"/>
</p>

---

## 🔄 Internal Flow for Token Creation

This flow explains what happens behind the scenes when a token is created — including contract deployment/interactions, metadata linking, and backend processes (if any).

<p align="center">
  <img src="../public/workflows/Internal-flow-create.png" width="600"/>
</p>

---

## 📦 Fetch Token Metadata

This workflow shows how token metadata is retrieved using the token URI. It includes fetching details like title, description, and other attributes stored off-chain or on-chain.

<p align="center">
  <img src="../public/workflows/fetch-token-metadata.png" width="600"/>
</p>

---

## 👍 Attestation Flow

Users can attest a token to validate or support it. This process includes wallet confirmation, on-chain verification, and updating the attestation state.

<p align="center">
  <img src="../public/workflows/attestation-flow.png" width="600"/>
</p>

---

## 🔄 Un-Attestation Flow

This flow allows users to remove their attestation. It ensures proper validation and updates the blockchain state accordingly while maintaining data integrity.

<p align="center">
  <img src="../public/workflows/unAttestation-flow.png" width="600"/>
</p>

---

## 🔍 Auto-fetch Metadata via Token URI

Wallets and applications can automatically fetch token metadata using the token URI. This improves usability by displaying token details without manual input.

<p align="center">
  <img src="../public/workflows/tokenUri.png" width="600"/>
</p>

---

> 💡 These workflows provide a clear understanding of how users and the system interact, covering both user-facing actions and internal processes.
