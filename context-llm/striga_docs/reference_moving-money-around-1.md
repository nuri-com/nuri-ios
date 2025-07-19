---
title: Moving Money Around
source_url: https://docs.striga.com/reference/moving-money-around-1
scraped_at: 2025-07-18 17:54:16
---

# Moving Money Around

> 🚧
>
> ### Sandbox
>
> On the sandbox environment, all operations on USDT have been stopped. Existing users holding USDT will not be able to initiate on-chain transactions, intra/inter transfers, or make on-chain deposits to their USDT accounts.

There are largely three types of transactions possible on the Striga platform and these are configured depending upon the model selected during application setup.

**Please note that when transacting, all currency amounts are denominated in the lowest divisible unit of the account currency and floating point numbers are not accepted.**

Please keep in mind the following checks applied when funds are moved around -

1. Intra Ledger transactions are those that move funds between accounts owned by the same type of identity, i.e. between consumers or between corporates.
2. Inter Ledger transactions are those that move funds between accounts owned by different types of identities, i.e. between consumers and corporates.
3. Swaps exchange currencies between accounts denominated in different currencies, owned by the same user.
4. Fund movements between users can only be performed in the same currency for both Intra and Inter Ledger Transactions.
5. All fund movements are subject to two-factor authentication. except for corporate initiated transactions.

> 📘
>
> ### Tip: Managing more than one wallet per user?
>
> Use the `/swap` API to move funds between different or the same currency(ies) of different or same wallet(s) of one single user.

![](https://files.readme.io/dde8d6d-image.png)

## Two Factor Authentication for Transactions

Every transaction on behalf of onboarded entities (consumers or businesses) which leaves an account must be initiated and confirmed by the entity that owns the account. Remember, funds on account belong to the onboarded end user, not you and to remain compliant we must ensure that any movement of funds is done at the request of a user.

This is achieved through the combination of the `Initiate` and `Confirm` endpoints. You can initiate transactions at which point an SMS OTP is sent to the user. This is collected through your application and then submitted to the `Confirm` endpoint to process the transactions. Upto 5 SMS requests can be made to resend an OTP for a transaction, each with an expiry as denoted in the response of the `Initiate` API.

## Inter Ledger Transactions

Inter ledger transactions represent those transactions that occur between identities of different denominations, either between yourself (a corporate) and your user or vice versa.

![](https://files.readme.io/bfe15ba-inter.png)

## Intra Ledger Transactions

Intra ledger transactions represent those transactions that occur between identities of the same denomination, either between two consumers or two corporates.

![](https://files.readme.io/7eeead5-image.png)

## Outgoing Transactions

Sending funds outside of the Striga ecosystem either using banking or crypto rails, depends upon the account currency denomination.

For EUR accounts, SEPA, and Instant SEPA are available and the `out` API takes an IBAN + BIC as input.

For Bitcoin accounts, on chain transactions and Lightning transactions are available and take in legacy, segwit, bech32, taproot and Lightning invoices respectively as appropriate.

For crypto accounts, on chain transactions can be made by specifying an address.

> 📘
>
> ### Moving money between two user accounts
>
> If you have two enriched Bitcoin accounts for example, under two different accounts, each with a different deposit address and you would like to move funds between these accounts, use the Intraledger method, as these internal movements between user wallets do not need to be on-chain, saving you on-chain fees.

## Receiving Money

To receive money into accounts, they must first be "enriched" with a deposit credentials. Enrichments are chargeable actions.

For example - Euro accounts can be enriched with IBANs and crypto accounts can be enriched with deposit addresses.

## SEPA Transactions

Once a EUR account has been enriched, the `/enrich` API returns bank credentials which consist of an IBAN and a BIC that can be used to send/receive EUR over SEPA to/from accounts in the same name as the account holder. Please ensure that when sending or receiving funds to IBANs, a message is displayed to your users to only send/receive funds from accounts at other banks/institution that are in their own name. Transfers to/from third parties will fail.

You can simulate the various states of a SEPA transaction on the sandbox, using the simulator. When a deposit is completed a webhook is sent to you and the balance updated. When a SEPA withdrawal is requested, it goes from `INITIATED` to `COMPLETED` or `FAILED`. You can simulate these states as well using the `SEPA Status Simulator` API in the Postman collection that can be [downloaded from the dashboard.](https://portal.striga.com)

![](https://files.readme.io/38602ed-SEPA.png)

## Blockchain Transactions

Once a crypto account has been enriched, you can deposit funds to this address for that user on chain. You can create as many unique deposit addresses for a user as you like by creating new wallets and new accounts and enriching them. Webhooks are sent for PENDING & CONFIRMED statuses as detailed in the "Webhooks" section of the documentation.

Withdrawing funds via an on-chain transfer is a three step process -

1. Whitelist the destination address
2. Initiate an on chain withdrawal request using the whitelisted address ID
3. Confirm an on chain withdrawal request using the SMS OTP sent to the user.

Below are a list of supported blockchain networks for crypto withdrawals, which is also used in the `network` key of your withdrawal request.

| Currency | Network | Chain ID (TESTNET) | Chain ID (MAINNET) |
| --- | --- | --- | --- |
| BTC | BTC |  |  |
| USDT | ETH | 11155111 | 1 |
| USDC | ETH | 11155111 | 1 |
| ETH | ETH | 11155111 | 1 |
| BNB | BSC | 97 | 56 |
| POL | POLYGON | 80002 | 137 |
| USDC\_POLYGON | POLYGON | 80002 | 137 |
| SOL | SOL |  |  |
| USDC\_SOL | SOL |  |  |

When initiating an on chain withdrawal, a `feeEstimate` is returned, depending upon the prevailing blockchain network fees at the moment, of which, the following items are present -

All values below are in the lowest denomination of that currency, i.e. in sats, wei or cents.

1. `totalFee` - The total fee for this transaction in that transactions' currency. This is the sum of your configured fee + our fee.
2. `ourFee` - Our transaction fee in that transactions' currency.
3. `theirFee` - Fee paid to your application, configured in your dashboard
4. `networkFee` - Fee paid to the blockchain network
5. `feePerByte`- If available, for UTXO based assets (Bitcoin)
6. `gasLimit` - If available, for EVM based assets (Ethereum)
7. `gasPrice` - If available, for EVM based assets (Ethereum)

## Collecting Fees

Starting in v1, you can configure custom fee percentages in the Striga dashboard to collect fees from your users for certain transaction types. These fees are automatically deducted from the user at the time of a transaction and delivered to your account in that currency. Striga's own fees are taken directly from this only in the following cases -

1. On Chain withdrawals
2. Lightning Network Transactions
3. Crypto exchanges

Other transaction fees are charged to you at the end of each billing cycle and *not* to the user.
