# Deployments

All deployments of contracts in this repo, including test/beta versions, are documented in this file. 
This file lists the addresses of the contracts that have been deployed 
as well as the constructor parameters that have been used.


| Network | Network ID | Version | Contract `IdentitySystem.sol` Address | Contract `IdentitySystem.sol` Parameters | Contract `ProfileSystem.sol` Address | Contract `ProfileSystem.sol` Parameters | Comments |
|---|---|---|---|---|---|---|---|
| Sepolia (Testnet) | 11155111 | v0.0.1 | `0xe886929760A5B8E47Cb42679512C920Fd1b14431` | None | `0xDf36b4Cc1fB9d65CB371e0ee88EB9e4b4A30E423` | None | Initial Sepolia Testnet deployment |
| Sepolia (Testnet) | 11155111 | v0.0.2 | `0xB0E21B4901DD434A2e49C983529eB7094bf4D978` | None | `0xDc9058F434299c619Dc6f885F850ee133327DA4e` | `_identitySystem` | Renames `endorse` → `attest` (all selectors changed) and drops `age` from `ProfileMetadata`. Supersedes v0.0.1; state is not migrated. |
| Sepolia (Testnet) | 11155111 | v0.0.3 | `0x82b049805626202D04c7450b386732B34180D634` | None | `0x34bC039aD24cd2c13b093847612180FdbEAdC78a` | `_identitySystem` | Adds paged attestation queries and the detailed attester view. Supersedes v0.0.2; state is not migrated. |
| Sepolia (Testnet) | 11155111 | v0.0.4 | `0x4F9A3a0a3f1f6A46b4DC862F15923321b40E96C0` | None | `0x62Decd4cEDd40e4816418034b54A5396f487379C` | `_identitySystem` | Flattens `AttesterView` to carry the attester's `displayName` beside the `Attestation` struct, replacing `profileTokenId`. Supersedes v0.0.3; state is not migrated. |
| Sepolia (Testnet) | 11155111 | v0.0.5 | `0x7e4d3e0b03353Bc344e50FB315e3CAC56385F44C` | None | `0xf5252b758f777B44fDC247ab97388bF6B1c44A7D` | `_identitySystem` | Typed token ids (`id-`/`tk-`/`pf-` per-type serials with `tokenURI` labels) and editable profiles (`updateProfile`, avatar, 6 fixed custom-link slots). Supersedes v0.0.4; state is not migrated. |
| Sepolia (Testnet) | 11155111 | v0.0.6 | `0x15253A56CD3EbC2893914C2139094dc92a42c016` | None | `0x17dc6AA09432d61ca630b523DAF01fB2b98Bd58D` | `_identitySystem` | Unbounded custom links: `LinkUpdate` takes a `uint32 index` and `getLinks(tokenId, offset, limit)` is paginated. Supersedes v0.0.5; state is not migrated. |


---
**Note to Developers:** After making a new deployment, please:
1. create a git tag for the deployed version;
2. add a new row to the table above with the details of the deployment.