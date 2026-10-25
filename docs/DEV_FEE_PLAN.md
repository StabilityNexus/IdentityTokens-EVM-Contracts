# Dev fee (donation to AOSSIE): plan

Status: implemented on `feat/dev-fee` in `contracts` and `dit`, not committed and not deployed. Updated 2026-10-25.
The owner-facing guide is [`DEV_FEE_OWNER_GUIDE.md`](DEV_FEE_OWNER_GUIDE.md).

## 1. Goal

Every user action in dit can carry a small donation to AOSSIE (a non-profit), about the size of that transaction's gas fee. The contracts accept a donation of any amount but never require one. dit adds it through a pre-ticked checkbox that the user can untick.

## 2. Decisions

| Topic | Decision |
|---|---|
| Names | `dev`, `devFee`, `devFeeReceiver` |
| What `devFee` means | A percentage of the transaction's gas fee: 100 = equal to it, 0 = off. Nobody has to update it as gas prices move |
| Cap | `MAX_DEV_FEE` = 5000 (50× the gas fee), a constant. A percentage cap never goes stale, unlike a cap in ETH |
| Set at deployment | `dev`, `devFeeReceiver`, `devFee` via the `IdentitySystem` constructor; all three are the AOSSIE wallet / 100 by default |
| Who computes the amount | dit, at click time: estimated gas of that exact call × `eth_gasPrice` × `devFee` / 100. The contract can't: `msg.value` is fixed before the gas price and gas used are known |
| Contract check | None on the amount. Any `msg.value` is accepted (the donation is optional anyway) |
| Which functions | All nine user writes: `createRootIdentity`, `createToken`, `transferToken`, `burnToken`, `attestToken`, `revokeAttestation`, `flagToken`, `createProfile`, `updateProfile` |
| Shared `dev` | One set of settings in `IdentitySystem`; one propose/accept covers both contracts |
| Where the money sits | In each contract until `withdrawDevFees()` (pull, no transfer per user transaction) |
| Who withdraws | Only `dev`. One call collects from both contracts and sends everything to `devFeeReceiver` |
| Change `dev` | `proposeDev(newDev)` by `dev` (`address(0)` cancels), then `acceptDev()` by the new address |
| Chains | One codebase for every EVM chain, including Ethereum Classic. Each chain is a separate deployment with its own settings and donations |

## 3. Contracts

- `src/modules/DevFeeModule.sol`: the settings, `MAX_DEV_FEE`, and the dev-only setters and handover.
- `IdentitySystem`:
  - inherits `DevFeeModule`; its constructor takes `(_dev, _devFeeReceiver, _devFee)`;
  - its four user writes are `payable`;
  - `withdrawDevFees()` sweeps `ProfileSystem` through `sweepDevFees` and sends both balances on.
- `AttestationModule`, `FlagModule`, `ProfileSystem`: their user writes are `payable`. `ProfileSystem.sweepDevFees` is callable only by `IdentitySystem`.
- Errors: `NotDev`, `NotPendingDev`, `DevFeeTooHigh`, `DevFeeTransferFailed`.
- Events: `DevFeeSet`, `DevFeeReceiverSet`, `DevTransferProposed`, `DevTransferred`, `DevFeesWithdrawn`.
- Deploy config (`HelperConfig`):
  - Anvil uses local accounts.
  - Every other chain reads `PRIVATE_KEY`, plus optional `DEV`, `DEV_FEE_RECEIVER` and `DEV_FEE`.
  - `make deploy FLAGS="…"` passes extra flags. Ethereum Classic needs `--legacy`, because it has no EIP-1559.
- Ethereum Classic compatibility:
  - OpenZeppelin 5.5 only compiles with `evm_version = cancun`.
  - ETC stops at Shanghai. `test/EvmCompat.t.sol` fails if the deployed code ever contains a Cancun-only opcode.
- Size: `IdentitySystem` 18,624 bytes (+1,075), 5,952 under the limit.

## 4. Frontend (dit)

- **Wiring:**
  - ABIs regenerated from `contracts/out`.
  - Dev-fee error messages in `lib/errors.ts`.
  - `lib/devFee.ts` (`donationAmount`, `describeDevFee`, `parseDevFeeInput`), checked by `npm run check:devfee`.
- **Write hooks:**
  - Each of the nine takes a `donate` flag.
  - A shared `useDonation` computes the value at click time.
  - "Preparing" counts as pending, so buttons stay disabled during the estimate.
  - Nothing is donated if the box is unticked, `devFee` hasn't loaded, or the estimate fails (the wallet then shows why the call fails).
- **`DonationCheckbox`:**
  - Pre-ticked, labelled "Donate to AOSSIE", with "Equal to / N% of this transaction's network fee" underneath.
  - Hidden when `devFee` is 0.
  - Placed in `/claim`, `RegistrationModal`, `AttestModal`, `CreateTokenModal`, `CreateProfileModal` (create and edit) and `TokenForm` (burn and transfer).
  - Each form opens ticked again.
- **`ConfirmTxModal`:**
  - The one-click Revoke (search dropdown, profile page) and Flag (search ⋮ menu) now open a small confirm step that carries the checkbox.
  - Confirming closes it, and the existing inline status shows progress.
- **`/dev-fee` page:**
  - Shows the waiting donations, the fee percentage, the receiver and the dev.
  - Offers Withdraw, Donation amount, Receiver, and Hand over (with Cancel).
  - A proposed wallet sees only Accept; any other wallet gets a one-line explanation.
  - The **Dev fee** sidebar item renders only for the dev or the proposed dev.
  - `/dev-fee` can't clash with a username, since usernames can't contain `-`.

## 5. Verified

- **Contracts:**
  - `forge test`: 138 passed (115 existing, 22 dev-fee, 1 EVM compatibility).
  - Prettier check clean; `forge build --sizes` OK.
  - Slither: 17 findings vs 15 on `main`. The 2 new ones are missing zero-address checks that are intended: `proposeDev(address(0))` cancels, and `sweepDevFees` is only called by IdentitySystem with the receiver.
- **ETC dry run:**
  - Anvil with chain id 61 and `--hardfork shanghai`, deployed with `--legacy`.
  - `dev`/receiver defaulted to AOSSIE and `DEV_FEE=250` was applied.
  - A claim and a token creation with donations went through, and a withdrawal swept the contract.
- **dit:** `tsc`, `eslint`, prettier and all `check:*` scripts pass.
- **Browser end to end** (static build, headless Chrome, local chain):

  | Action | Result |
  |---|---|
  | Claim, box ticked | Donation equal to that transaction's gas fee (ratio 1.000) |
  | Attest, box unticked | No donation |
  | Revoke via the confirm popup | Ratio 1.045 (the estimate runs slightly above actual gas) |
  | Flag at `devFee` 250% | Ratio 2.500 |
  | Sidebar | Item shows for the dev, not for a regular wallet |
  | Withdraw | Swept both contracts to the receiver |
  | Fee input | 5001% rejected in the form; 250% saved |
  | Handover | Propose, then accept from the new wallet |

  Screenshots are in `~/Desktop/ss-proof/dev-fee`.

## 6. Rollout

1. **Order:** the dit work sits on top of the open dit PR #142 (unbounded links, v0.0.6 ABI), so #142 merges first.
2. **Issues first:** per AGENTS.md §6, open the contracts and frontend issues and raise this on Discord.
3. **Contracts:** PR, then merge.
4. **Sepolia:** deploy v0.0.7, then add the Deployment.md row and the tag.
5. **dit:** PR with the feature commit plus a separate address commit.
6. **Owner:** hand over `DEV_FEE_OWNER_GUIDE.md` with the addresses filled in.

## 7. Follow-ups found along the way (not part of this change)

- **ETC in dit:**
  - dit's wagmi config lists Sepolia and Polygon only.
  - Explorer links are hard-coded to Sepolia Etherscan.
  - Serving an ETC deployment needs the `classic` chain, per-chain contract addresses, and per-chain explorer links.
- **Discover Revoke stub:** the token card's Revoke on `/discover` is a stub (`console.log` only) and shows whether or not the viewer attested.
- **Hydration warning:** `/claim` logs React hydration error #418 on first load for a connected wallet that has not claimed yet. It happens on `main` too.
