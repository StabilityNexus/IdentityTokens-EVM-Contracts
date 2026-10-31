# AGENTS.md — Developer & AI Agent Guidelines

This repository contains smart contracts powering the **IdentityTokens-EVM** protocol under [Stability Nexus](https://stability.nexus/). It is built with Solidity, Foundry, and OpenZeppelin contracts.

---

## 1. Project Overview & Architecture

### Purpose
IdentityTokens-EVM is a decentralized identity protocol on EVM-compatible blockchains. It allows users to self-issue soulbound root identity tokens and non-soulbound/transferable identity and profile tokens (ERC-721 based DIT tokens) with customizable, editable metadata (name, username, nationality, social links, avatar, any number of custom links). The protocol features peer attestation with time clamping and revocation, trust flagging with auto-flag thresholds, and username-based profile resolution.

### Core Architecture & Directory Map

- **`src/` — Core Smart Contracts**
  - [`src/IdentitySystem.sol`](/contracts/src/IdentitySystem.sol): Core contract inheriting `ERC721`, [`DevFeeModule`](/contracts/src/modules/DevFeeModule.sol), [`AttestationModule`](/contracts/src/modules/AttestationModule.sol), and [`FlagModule`](/contracts/src/modules/FlagModule.sol). Manages soulbound root identities, sub-token issuance, transfer permissions, wallet/root token indexing, on-chain `tokenURI` labels, and integration with `ProfileSystem`.
    - **Token IDs:** each type has its own counter (`minted[TokenType]`). `id = (type + 1) * 1e10 + (serial * MIX + type * SALT) % 1e10`, so `tokenTypeOf(id)` decodes the type with no storage, and `formatTokenId(id)` gives the UI form `id-`/`tk-`/`pf-` + 10 digits (e.g. `29321932540` → `tk-9321932540`). The frontend mirrors this in `dit/lib/tokenId.ts`.
  - [`src/ProfileSystem.sol`](/contracts/src/ProfileSystem.sol): Standalone system for profile metadata management, username registration/validation (`a-z`, `0-9`, `.`, `_`), profile metadata mapping (`DataTypes.ProfileMetadata`), per-field and per-link edits via `updateProfile` (username is permanent), an unbounded custom-link list edited by index and read in pages (`getLinks`), and username/metadata release upon token burn (links stay in storage, but `getLinks` returns nothing for a burned profile).
  - [`src/modules/DevFeeModule.sol`](/contracts/src/modules/DevFeeModule.sol): Abstract module for the optional donation to AOSSIE. Every user action in both contracts is `payable` and accepts any amount; the ETH stays in the contract. `devFee` is a percentage of the transaction's gas fee (100 = equal to it, capped at `MAX_DEV_FEE` = 5000) that frontends use to compute the donation. Only `dev` can `setDevFee`, `setDevFeeReceiver`, hand the role over with `proposeDev` → `acceptDev`, and call `IdentitySystem.withdrawDevFees()`, which also sweeps `ProfileSystem` (`sweepDevFees`) and sends everything to `devFeeReceiver`.
  - [`src/modules/AttestationModule.sol`](/contracts/src/modules/AttestationModule.sol): Abstract module handling time-bound peer attestations (up to 3 years max), attestation clamping based on token expiration, active attestation queries, and revocations. Neither a token's creator nor its current holder can attest it.
  - [`src/modules/FlagModule.sol`](/contracts/src/modules/FlagModule.sol): Abstract module managing manual flagging by root identities and automated flagging on revocation (auto-flags once when a token has at least 20 lifetime attesters and at least 1/3 of them have revoked; manual flags only increment `flagCount`). Only roots at least `MIN_ROOT_AGE` (30 days) old can flag, and only their attestations and revokes count toward auto-flag.
  - [`src/libraries/DataTypes.sol`](/contracts/src/libraries/DataTypes.sol): Shared data structures: `TokenType` enum (`ROOT`, `SUB`, `PROFILE`), `RootIdentity`, `Token`, `RootIdentityView`, `Attestation`, `AttesterView`, `ProfileMetadata`, and the profile-edit types `ProfileField`, `FieldUpdate`, `ProfileLink`, `LinkUpdate`.
  - [`src/libraries/Errors.sol`](/contracts/src/libraries/Errors.sol): Centralized custom Solidity error definitions organized by subsystem (Transfer, Identity, Profile, Token, Attestation, Flag, Admin, Dev fee).
  - [`src/libraries/Events.sol`](/contracts/src/libraries/Events.sol): Centralized Solidity event declarations (`RootIdentityCreated`, `ProfileCreated`, `ProfileUpdated`, `TokenCreated`, `TokenTransferred`, `TokenBurned`, `AttestationGiven`, `AttestationRevoked`, `TokenFlagged`, `TokenAutoFlagged`, `ProfileSystemSet`, `DevFeeSet`, `DevFeeReceiverSet`, `DevTransferProposed`, `DevTransferred`, `DevFeesWithdrawn`).

- **`script/` — Deployment & Maintenance**
  - [`script/Deploy.s.sol`](/contracts/script/Deploy.s.sol): Foundry deployment script deploying `IdentitySystem` and `ProfileSystem`, and wiring `setProfileSystem`.
  - [`script/HelperConfig.s.sol`](/contracts/script/HelperConfig.s.sol): Network configuration. Anvil (31337) uses fixed local accounts; any other chain reads `PRIVATE_KEY`, plus optional `DEV`, `DEV_FEE_RECEIVER` (both default to the AOSSIE wallet) and `DEV_FEE` (default 100).

- **`test/` — Automated Test Suite**
  - [`test/utils/BaseTest.sol`](/contracts/test/utils/BaseTest.sol): Shared `setUp` that deploys and wires both contracts, plus small helpers (`_root`, `_token`, `_profile`, `_meta`, `_ageRoots`, `_createAttesters`).
  - [`test/unit/`](/contracts/test/unit): One file per feature: `RootIdentity`, `Token`, `TokenIds`, `Attestation`, `AttestationViews`, `Flag`, `Profile`, `ProfileEdit` and `DevFee` (donations, withdrawal, dev-only settings and the two-step dev handover).
  - [`test/integration/Deploy.t.sol`](/contracts/test/integration/Deploy.t.sol): Runs `Deploy` on Anvil and checks `HelperConfig` reads the deployer key and dev-fee settings from the environment on other chains.
  - [`test/integration/EvmCompat.t.sol`](/contracts/test/integration/EvmCompat.t.sol): Fails if the deployed code uses an opcode Ethereum Classic lacks (Cancun's `MCOPY`, `TLOAD`, `TSTORE`, `BLOBHASH`, `BLOBBASEFEE`).

- **`docs/` — System Workflows**
  - [`docs/WORKFLOWS.md`](/contracts/docs/WORKFLOWS.md): Visual and structural workflow guides.
  - [`docs/UserFlow.md`](/contracts/docs/UserFlow.md): Detailed user interaction sequences.

---

## 2. Setup & Environment

### Tool Requirements & Versions
- **Node.js**: `>= 18.0.0` (used for Prettier formatting and Solhint linting)
- **Foundry Toolchain**: `forge`, `cast`, `anvil` (installed via `foundryup`)
- **Solidity Compiler (`solc`)**: `0.8.24` (configured in [`foundry.toml`](/contracts/foundry.toml))
- **Package Managers**: `npm` (Node dependencies) & `git submodules` (Foundry libraries in `lib/`)

### Installation Steps

1. **Install Node.js dependencies:**
   ```bash
   npm install
   ```

2. **Install Foundry (if not already present):**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

3. **Install Smart Contract Dependencies (OpenZeppelin & Forge Std):**
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts
   forge install foundry-rs/forge-std
   ```
   *Or run `make install` / `make all`.*

### Environment Variables (`.env`)
Create a `.env` file in the project root with the following variables:

```env
PRIVATE_KEY=0x...                     # Deployment private key
RPC_URL=https://...                   # Network RPC URL (e.g. Sepolia or mainnet)
SEPOLIA_RPC_URL=https://...           # Sepolia RPC URL
IDENTITY_SYSTEM_ADDRESS=0x...         # Address of deployed IdentitySystem contract
PROFILE_SYSTEM_ADDRESS=0x...          # Address of deployed ProfileSystem contract
DEV=0x...                             # Optional: dev role (default: AOSSIE wallet)
DEV_FEE_RECEIVER=0x...                # Optional: where withdrawn donations go (default: AOSSIE wallet)
DEV_FEE=100                           # Optional: donation as a percent of the gas fee, at most 5000 (default: 100)
```

---

## 3. Build, Run, and Test Commands

### Smart Contract Compilation
- **Build contracts:**
  ```bash
  forge build
  ```
  *(or `npm run build` / `make build`)*

- **Check contract sizes:**
  ```bash
  forge build --sizes
  ```

- **Clean build artifacts:**
  ```bash
  forge clean
  ```
  *(or `make clean`)*

### Running Tests
- **Run all tests:**
  ```bash
  forge test
  ```
  *(or `make test`)*

- **Run tests with gas report:**
  ```bash
  forge test --gas-report
  ```

- **Run tests with high verbosity (stack traces & logs):**
  ```bash
  forge test -vvv
  # or for maximum verbosity:
  forge test -vvvv
  ```

- **Run a single test by name:**
  ```bash
  forge test --match-test test_CreateProfile
  ```

- **Run tests in a single contract or file:**
  ```bash
  forge test --match-contract FlagTest
  forge test --match-path test/unit/Flag.t.sol
  ```

### Code Formatting & Linting
- **Format all Solidity files (Prettier):**
  ```bash
  npm run sol-fmt-all
  ```

- **Format a single file:**
  ```bash
  npm run sol-fmt
  ```

- **Check Solidity code formatting (CI check):**
  ```bash
  npm run sol-check-all
  ```

- **Run Solhint linter:**
  ```bash
  npx solhint "src/**/*.sol"
  ```

- **Run Slither static analysis:**
  ```bash
  slither .
  ```

### Deployment Commands
- **Deploy to local Anvil node:**
  ```bash
  make deploy-anvil
  ```

- **Deploy to live network (uses `.env` settings):**
  ```bash
  make deploy
  # or:
  npm run deploy
  ```
  The script is chain agnostic: `RPC_URL` picks the chain (Ethereum, Ethereum Classic, or a testnet such as Sepolia or Mordor). Each chain gets its own independent deployment, with its own `dev`, `devFee` and donations. Extra `forge script` flags go in `FLAGS`:
  ```bash
  # Ethereum: verify on Etherscan
  make deploy FLAGS="--verify"
  # Ethereum Classic has no EIP-1559, so send legacy transactions; verify on Blockscout
  make deploy FLAGS="--legacy --verify --verifier blockscout --verifier-url https://etc.blockscout.com/api/"
  ```

---

## 4. Code Style & Conventions

### Formatting Standards
- **Compiler Version**: Fixed to `pragma solidity ^0.8.24;`
- **Formatter**: Prettier with `prettier-plugin-solidity`
- **Line Length**: `120` characters ([`foundry.toml`](/contracts/foundry.toml) & [`.prettierrc`](/contracts/.prettierrc))
- **Indentation**: 4 spaces, no tabs (`useTabs: false`)
- **Quotes**: Double quotes (`"`)

### Naming Conventions
- **Contracts / Libraries / Interfaces**: PascalCase (e.g. `IdentitySystem`, `ProfileSystem`, `DataTypes`)
- **Internal / Private Variables & Functions**: Leading underscore `_` (e.g. `_nextId`, `_internalTransferActive`, `_validateUsername`)
- **Public / External Functions & Storage Mappings**: camelCase (e.g. `createRootIdentity`, `ownerToRootId`)
- **Enums & Structs**: PascalCase types (`TokenType`, `ProfileMetadata`); UPPERCASE enum values (`ROOT`, `SUB`, `PROFILE`)
- **Custom Errors**: PascalCase error names starting with action or condition (e.g. `AlreadyHasRoot`, `ProfileUsernameTaken`, `RootNonTransferable`)

### Structural & Architectural Idioms
- **Centralized Types, Errors & Events**:
  - All struct definitions must live in [`src/libraries/DataTypes.sol`](/contracts/src/libraries/DataTypes.sol).
  - All custom revert errors must live in [`src/libraries/Errors.sol`](/contracts/src/libraries/Errors.sol).
  - All events must live in [`src/libraries/Events.sol`](/contracts/src/libraries/Events.sol).
- **O(1) Array Maintenance**: Use swap-and-pop with index tracking mappings (`_walletTokenIndex`, `_rootTokenIndex`) when removing token IDs from dynamic arrays.
- **Transfer Restrictions**: Direct ERC721 transfers are disabled; transfers must route through system-controlled internal methods (`_internalTransferActive`). `ROOT` identity tokens are non-transferable (soulbound).

---

## 5. Testing Guidelines

### Framework & Setup
- Primary framework is **Foundry** (`forge-std`).
- Test contracts extend `Test` from `forge-std/Test.sol`. Unit tests do it through `BaseTest` ([`test/utils/BaseTest.sol`](/contracts/test/utils/BaseTest.sol)), which holds the shared setup and helpers.
- Tests live in [`test/unit/`](/contracts/test/unit) (one file per feature) and [`test/integration/`](/contracts/test/integration), with the file extension `.t.sol`.

### Test Writing Conventions
- **Success Case Tests**: `test_<FunctionName>_<Scenario>()`
  - Example: `test_CreateProfile()`, `test_AttestToken_3YearDuration()`
- **Failure / Revert Case Tests**: `test_RevertIf_<FunctionName>_<Reason>()`
  - Example: `test_RevertIf_CreateProfile_AlreadyMinted()`, `test_RevertIf_TransferToken_Root()`
- **Assertions & Cheats**: Use `vm.prank(address)`, `vm.expectRevert(Errors.<ErrorName>.selector)`, `vm.expectEmit(...)`, `assertEq(...)`, `assertTrue(...)`.
- **Fuzzing**: Standard fuzz tests run 256 iterations locally and 1000 iterations in CI (`profile.ci.fuzz`).

---

## 6. Git & PR Conventions

### Workflow Rules
1. **Issue Assignment First**: You **must** get an issue assigned to you before writing code.
2. **Discord Architecture Discussion**: Major architectural, storage, or logic changes **must** be discussed on Discord before implementation.
3. **Branch Naming Scheme**:
   - `feature/<short-description>` (or `feat/<short-description>`)
   - `fix/<short-description>`
   - `refactor/<short-description>`
   - `docs/<short-description>`
   - `chore/<short-description>`

### Commit Message Format
Follow Conventional Commits:
```
<type>(<scope>): <short description>
```
*Examples:*
- `feat(profile): add username to profile token id mapping`
- `fix(errors): add OnlyIdentitySystem custom error`
- `refactor: optimize array removal with swap-and-pop`
- `docs: update NatSpec comments`

### Pull Request Guidelines
- Always link the target issue (`Closes #<issue-number>`).
- Include a detailed description of changes, motivation, security impact, and gas changes.
- Ensure all CI workflows pass:
  - `npm run sol-check-all` (Solidity formatting)
  - `forge build --sizes` (Contract compilation & size limits)
  - `forge test -vvv` (Test suite execution)
  - `slither` (Static analysis)

---

## 7. Do's and Don'ts (Gotchas & Security)

### DO's
- **DO** run `npm run sol-fmt-all` before pushing code.
- **DO** write unit and revert tests for any modified or new contract logic.
- **DO** document all external/public functions using standard NatSpec comments (`@notice`, `@param`, `@return`).
- **DO** enforce strict username rules: 3–32 chars, restricted to lowercase `a-z`, `0-9`, `.`, `_`.
- **DO** keep error definitions in `Errors.sol` and event definitions in `Events.sol`.
- **DO** make every new user action `payable`, so it can carry the optional donation (any amount).
- **DO** keep `test/integration/EvmCompat.t.sol` passing: OpenZeppelin 5.5 needs `evm_version = cancun` to compile, but the deployed code must also run on Ethereum Classic, which stops at Shanghai.

### DON'Ts
- **DON'T** edit auto-generated build files or directories ([`out/`](/contracts/out), [`cache/`](/contracts/cache), [`broadcast/`](/contracts/broadcast)).
- **DON'T** modify external dependencies in [`lib/`](/contracts/lib) or [`node_modules/`](/contracts/node_modules).
- **DON'T** declare custom errors or events inline inside contract files.
- **DON'T** allow transfer of `ROOT` identity tokens — root identities are strictly soulbound.
- **DON'T** allow multiple profiles per wallet (`hasMintedProfile` is a permanent guard).
- **DON'T** push code that fails formatting (`npm run sol-check-all`).

---

## 8. Dependencies & Core Libraries

| Dependency | Purpose | Version / Source |
| :--- | :--- | :--- |
| **Solidity** | Smart Contract Programming Language | `^0.8.24` |
| **OpenZeppelin Contracts** | ERC-721 base implementations & security standards | `^5.0.0` ([`lib/openzeppelin-contracts`](/contracts/lib/openzeppelin-contracts)) |
| **Forge Standard Library** | Testing framework & cheatcodes (`forge-std`) | `v1.9.6` ([`lib/forge-std`](/contracts/lib/forge-std)) |
| **Prettier & Plugin Solidity**| Code formatting | `prettier ^3.8.1`, `prettier-plugin-solidity ^2.2.1` |
| **Solhint** | Solidity linting | `solhint:recommended` |
| **Slither** | Static security analyzer | `crytic/slither-action@v0.3.0` |

---

## 9. Monorepo / Multi-Package Notes

This repository is currently structured as a single smart contract project root. If frontend components or additional sub-packages are introduced in future iterations:
- Keep this root `AGENTS.md` focused on core EVM smart contract standards.
- Place package-specific guidelines (e.g. for frontend apps or indexers) in nested `AGENTS.md` files within their respective subdirectories.
