# Managing DIT donations: guide for the AOSSIE wallet

> Draft. This describes the dev fee feature planned for DIT v0.0.7. The page and buttons below exist once that version is deployed, and the contract addresses are filled in then.

## What this is

Every action someone takes in DIT can include a donation to AOSSIE. This covers claiming a name, creating a profile, attesting, and so on.

- **How it's offered:** a checkbox, ticked by default, that the user can untick.
- **How much:** by default, the same amount as that transaction's network (gas) fee. It follows gas prices by itself, so nobody needs to adjust it day to day.
- **Where it goes:** the donations collect inside the DIT contracts until you withdraw them.

Your wallet, `0xda4772b474C4490D482094e836Dcae1979e0d6d4`, has two roles:

- **dev:** the only wallet that can:
  - withdraw donations;
  - change the donation percentage;
  - change where donations go;
  - hand the dev role to another wallet.
- **devFeeReceiver:** the wallet that receives withdrawals.

Nobody else can change these settings, including the DIT developers and the wallet that deployed the contracts.

Each network DIT runs on (for example Ethereum and Ethereum Classic) has its own separate contracts. Each has its own settings, its own donations and its own Withdraw button. Switch your wallet to a network to manage that network's donations.

## What you need

- The AOSSIE wallet in a browser wallet such as MetaMask or Rabby.
- The wallet set to the network you want to manage.
- A little of that network's coin (ETH, ETC, …) in the wallet, to pay gas for your own actions.

## Open the dev page

1. Go to **https://identity-tokens-evm-frontend.vercel.app/dev-fee**, or connect the AOSSIE wallet and click **Dev fee** in the sidebar. The item only appears for the dev wallet and for a wallet proposed as the next dev.
2. Connect the AOSSIE wallet.

The page shows:

- **Donations waiting:** collected and not yet withdrawn.
- **Donation:** the current percentage of each transaction's network fee.
- **Receiver** and **Dev.**

## Withdraw donations

1. Click **Withdraw**.
2. Confirm in your wallet.

Everything waiting in both DIT contracts is sent to the receiver in one transaction.

## Change the donation amount

The amount is a percentage of each transaction's network fee:

- **100:** the donation equals the fee (the default).
- **50:** half of it.
- **0:** turns donations off; the checkbox disappears for users.

The most it can be is 5000 (50× the fee).

1. Under **Donation amount**, type the percentage.
2. Click **Save** and confirm in your wallet.

## Change where donations go

1. Under **Receiver**, paste the new wallet address.
2. Click **Save** and confirm.

Future withdrawals go to the new address, including donations already waiting. Withdraw first if those should go to the current receiver.

## Hand the dev role to another wallet

This takes two steps, so the role can't be sent to a mistyped or wrong address.

1. From the current dev wallet, enter the new wallet's address under **Hand over the dev role**. Click **Propose** and confirm.
2. Let the owner of the new wallet know; the blockchain doesn't notify them.
3. They open the same page with the **new** wallet connected. It says "You've been proposed as the new dev". They click **Accept** and confirm.

Until step 3 is done, the current wallet stays dev. To cancel a proposal, click **Cancel** next to the proposed address.

## Good to know

- **Donations are optional.** Users can untick the box. Someone using the contracts directly, or through another app, can also send nothing.
- **Keep the wallet's key safe.**
  - If it's lost, nobody can withdraw the donations waiting in the contracts or change these settings. DIT itself keeps working normally.
  - If it's stolen, the thief can withdraw what's waiting. Withdrawing regularly keeps that amount small.
  - A multisig wallet (for example a Safe) as dev protects against a single stolen key. You can move the dev role to one at any time with the handover above.
- **Without the website:** the contracts are verified on the network's block explorer (Etherscan for Ethereum, Blockscout for Ethereum Classic). You can do the same actions from the contract's **Write Contract** tab:
  - `withdrawDevFees`
  - `setDevFee` (the percentage, for example `100`)
  - `setDevFeeReceiver`
  - `proposeDev`
  - `acceptDev`
  - IdentitySystem: _address added after deployment_
