# AGENTS.md — Developer & AI Agent Guidelines

This repository contains smart contracts powering the **IdentityTokens-EVM** protocol under [Stability Nexus](https://stability.nexus/). It is built with Solidity, Foundry, and OpenZeppelin contracts.

---

## 1. Project Overview & Architecture

### Purpose
IdentityTokens-EVM is a decentralized identity protocol on EVM-compatible blockchains. It allows users to self-issue soulbound root identity tokens and non-soulbound/transferable identity and profile tokens (ERC-721 based DIT tokens) with customizable metadata (name, username, age, nationality, social links). The protocol features peer attestation with time clamping and revocation, trust flagging with auto-flag thresholds, and username-based profile resolution.

### Core Architecture & Directory Map

- **`src/` — Core Smart Contracts**
  - [`src/IdentitySystem.sol`](/contracts/src/IdentitySystem.sol): Core contract inheriting `ERC721`, [`AttestationModule`](/contracts/src/modules/AttestationModule.sol), and [`FlagModule`](/contracts/src/modules/FlagModule.sol). Manages soulbound root identities, sub-token issuance, transfer permissions, wallet/root token indexing, and integration with `ProfileSystem`.
  - [`src/ProfileSystem.sol`](/contracts/src/ProfileSystem.sol): Standalone system for profile metadata management, username registration/validation (`a-z`, `0-9`, `.`, `_`), profile metadata mapping (`DataTypes.ProfileMetadata`), and username release upon token burn.
  - [`src/modules/AttestationModule.sol`](/contracts/src/modules/AttestationModule.sol): Abstract module handling time-bound peer attestations (up to 3 years max), attestation clamping based on token expiration, active attestation queries, and revocations.
  - [`src/modules/FlagModule.sol`](/contracts/src/modules/FlagModule.sol): Abstract module managing manual flagging by root identities and automated threshold-based flagging (`AUTO_FLAG_THRESHOLD = 3` flags with minimum active attestations check).
  - [`src/libraries/DataTypes.sol`](/contracts/src/libraries/DataTypes.sol): Shared data structures: `TokenType` enum (`ROOT`, `SUB`, `PROFILE`), `RootIdentity`, `Token`, `RootIdentityView`, `Attestation`, and `ProfileMetadata`.
  - [`src/libraries/Errors.sol`](/contracts/src/libraries/Errors.sol): Centralized custom Solidity error definitions organized by subsystem (Transfer, Identity, Profile, Token, Attestation, Flag, Admin).
  - [`src/libraries/Events.sol`](/contracts/src/libraries/Events.sol): Centralized Solidity event declarations (`RootIdentityCreated`, `ProfileCreated`, `TokenCreated`, `TokenTransferred`, `TokenBurned`, `AttestationGiven`, `AttestationRevoked`, `TokenFlagged`, `TokenAutoFlagged`, `ProfileSystemSet`).

- **`script/` — Deployment & Maintenance**
  - [`script/Deploy.s.sol`](/contracts/script/Deploy.s.sol): Foundry deployment script deploying `IdentitySystem` and `ProfileSystem`, and wiring `setProfileSystem`.
  - [`script/HelperConfig.s.sol`](/contracts/script/HelperConfig.s.sol): Environment and network configuration helper.

- **`test/` — Automated Test Suite**
  - [`test/IdentityToken.t.sol`](/contracts/test/IdentityToken.t.sol): Comprehensive test suite containing 72 unit, integration, and fuzz tests covering all contract flows and edge cases.

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
  forge test --match-contract IdentitySystemTest
  forge test --match-path test/IdentityToken.t.sol
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
- **Internal / Private Variables & Functions**: Leading underscore `_` (e.g. `_nextTokenId`, `_internalTransferActive`, `_validateUsername`)
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
- All test contracts inherit from `Test` in `forge-std/Test.sol`.
- Tests are located in the [`test/`](/contracts/test) directory with the file extension `.t.sol`.

### Test Writing Conventions
- **Success Case Tests**: `test_<FunctionName>_<Scenario>()`
  - Example: `test_CreateProfile()`, `test_AttestToken_3YearDuration()`
- **Failure / Revert Case Tests**: `test_RevertIf_<FunctionName>_<Reason>()`
  - Example: `test_RevertIf_CreateProfile_AlreadyMinted()`, `test_RevertIf_TransferRootToken()`
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
