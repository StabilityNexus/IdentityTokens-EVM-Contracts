# 🤝 Contributing to IdentityTokens-EVM-Contracts

Welcome to **IdentityTokens-EVM-Contracts** under Stability Nexus.

This repository contains Solidity smart contracts powering a decentralized identity protocol on EVM chains. Because this involves on-chain logic, security and discipline are mandatory.

Please follow this complete step-by-step guide from beginner level to final PR merge.

---

# 📜 1. Core Contribution Rules (Read First)

-   You MUST get the issue assigned before starting.
-   You MUST discuss major changes on Discord before coding.
-   You MUST write or update tests for contract changes.
-   You MUST run formatting and checks before committing.
-   You MUST NOT open PRs without linking an issue.

Security > Speed.

---

# 🧭 2. Complete Contribution Workflow (Step-by-Step)

## 🔎 Step 1: Find or Create an Issue

-   Browse existing issues.
-   If none exists, create one with:

    -   Clear title
    -   Problem description
    -   Expected behavior
    -   Technical reasoning

Do NOT start coding yet.

---

## 🙋 Step 2: Get Assigned

-   Comment: "I would like to work on this issue."
-   Wait for maintainer/knight approval.
-   Start only after assignment.

Unassigned PRs may be closed.

---

## 💬 Step 3: Discuss on Discord:

-   Join here :[discord](https://discord.com/channels/995968619034984528/1461697098767532269)

Before writing code:

-   Share your technical plan.
-   Explain storage changes (if any).
-   Mention security considerations.
-   Confirm architecture consistency.

This avoids wasted review cycles.

---

## 🍴 Step 4: Fork the Repository

Click **Fork** on GitHub.

This creates your own copy under your account.

---

## 💻 Step 5: Clone Your Fork

```
git clone https://github.com/YOUR-USERNAME/IdentityTokens-EVM-Contracts.git
cd IdentityTokens-EVM-Contracts
```

---

## 🔗 Step 6: Add Upstream Remote

```
git remote add upstream https://github.com/StabilityNexus/IdentityTokens-EVM-Contracts.git
```

Verify:

```
git remote -v
```

---

## 🌿 Step 7: Create a Branch

Never work on main.

```
git checkout -b feature/short-description
```

Examples:

-   feature/add-attestation-logic
-   fix/token-mapping-bug
-   refactor/storage-optimization
-   docs/update-natspec

---

# 🛠 3. Project Setup

## 📦 Install Node Dependencies

```
npm install
```

This installs:

-   Prettier
-   Prettier Solidity plugin
-   OpenZeppelin dependency

---

## 🧱 Install Foundry (If Not Installed)

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

## 📚 Install Solidity Libraries (if required)

```
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
```

---

# 🏗 4. Build & Test Commands

## 🔨 Build Contracts

You can use either:

```
forge build
```

Or npm script:

```
npm run build
```

---

## 🚀 Deploy Script (Advanced Users)

```
npm run deploy
```

This runs:

```
forge script script/Deploy.s.sol:Deploy --broadcast
```

Ensure correct RPC and private key configuration before broadcasting.

---

# 🧪 5. Testing Requirements

If your change modifies contracts:

-   Add or update Forge tests.
-   Test access control.
-   Test attestation logic.
-   Test edge cases.
-   Validate gas usage impact.

Run:

```
forge test
```

Gas report:

```
forge test --gas-report
```

Verbose:

```
forge test -vvvv
```

All tests must pass before pushing.

---

# 🎨 6. Solidity Formatting & Checks (MANDATORY)

Before committing, run:

### ✨ Format All Solidity Files

```
npm run sol-fmt-all
```

### 🔍 Check Formatting

```
npm run sol-check-all
```

You can also format a single file:

```
npm run sol-fmt
```

Or check formatting:

```
npm run sol-check
```

PRs failing formatting checks may be rejected.

---

# 🛡 7. Security & Code Standards

Because this is an EVM contract repository:

-   Use Solidity ^0.8.24 conventions.
-   Use OpenZeppelin correctly.
-   Add NatSpec documentation.
-   Avoid unbounded loops.
-   Avoid unnecessary storage writes.
-   Use require for validation.
-   Protect against reentrancy where needed.
-   Consider multiple identity tokens per user.
-   Validate attestation mappings carefully.

If possible, run Slither locally:

```
slither .
```

Security is non-negotiable.

---

# 📝 8. Commit Properly

```
git add .
git commit -m "feat: short clear description"
```

Good examples:

-   feat: add attestation validation check
-   fix: resolve identity mapping overwrite bug
-   refactor: optimize storage packing
-   docs: update natspec comments

Avoid vague messages like "update".

---

# 🔄 9. Sync With Upstream Before Pushing

```
git fetch upstream
git merge upstream/main
```

Resolve conflicts locally.

---

# 🚀 10. Push to Your Fork

```
git push origin feature/short-description
```

---

# 📬 11. Open a Pull Request

When opening PR:

-   Link issue (Closes #number)
-   Explain what changed
-   Explain why
-   Mention gas impact
-   Mention security considerations

PR must pass CI before review.

---

# ❌ What Causes Rejection

-   No assignment
-   No Discord discussion for major change
-   Missing tests
-   Formatting not applied
-   Failing CI
-   Breaking protocol logic

---

# 🤝 Code of Conduct
