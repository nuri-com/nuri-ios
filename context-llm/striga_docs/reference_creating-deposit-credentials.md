---
title: Creating Deposit Credentials
source_url: https://docs.striga.com/reference/creating-deposit-credentials
scraped_at: 2025-07-18 17:53:22
---

# Creating Deposit Credentials

By default, as detailed in the "Storing Value" section, a default wallet is provisioned for a user and each wallet contains one account **each** of the currencies enabled for your application. It is left up to you on how you use these accounts to manage your users' funds.

These accounts can be thought of as "boxes" that hold money in that specific currency for one user in that currency. By default, no account (except your corporate accounts & optional "DeFi" accounts) has a means of interacting with the outside world by means of the Bitcoin Network, Lightning Network, Ethereum Network, BSC network or a Bank Transfer.

To do this, you must "Enrich" an account with deposit credentials to be able to send & receive funds from the outside world. **Enriching a EUR account will give you an IBAN that connects to SEPA and enriching a crypto account will give you a unique, dedicated crypto address that can be used for that user specifically to interact with the respective blockchain.**

> 🚧
>
> ### Creating IBANs
>
> A single user identity can have a maximum of 10 IBANs attached to their name, i.e. this would reflect 10 separate wallets (each with a EUR account enriched).

On the sandbox, you can test the entire flow of deposits & withdrawals using test blockchain networks, added in the v1 API, as detailed below -

1. BTC - Bitcoin Testnet 3
2. BTC - Lightning Network Testnet
3. ETH - Sepolia Testnet
4. USDC - Sepolia Testnet (Contract 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
5. USDC\_POLYGON - Amoy Testnet (Contract 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582)
6. MATIC\_POLYGON - Polygon Testnet Amoy
7. SOL - Solana Devnet
8. USDC\_SOL – Solana Devnet (Contract 4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU)

More details on the exact contract used for tokens on the testnet can be fetched from the "Enrich" API.

## Managing Multiple Blockchain Networks

Starting Summer 2024, certain coins may allow deposits and withdrawals in multiple blockchain networks. If this is enabled for a particular account, a new key `multiChainSupport` will be set to `true` for that account and a new key `blockchainNetworks` will contain an array of supported networks.

For example, USDC is supported on Polygon , Ethereum and Solana:

JSON

```
{
    "accountId": "d83a547d8083ca367943742bec122821",
    "parentWalletId": "7f3c6174-7a83-4270-ba8e-51cd89e0b34f",
    "currency": "USDC",
    "ownerId": "ac69f412-efdb-4cf7-815a-13fd5bcf2a40",
    "ownerType": "CONSUMER",
    "createdAt": "2024-07-01T09:07:17.035Z",
    "availableBalance": {
        "amount": "1000",
        "currency": "cents",
        "hAmount": "10",
        "fiatEquivalentBalance": "929",
        "fiatCurrency": "EUR",
        "hFiatEquivalentBalance": "9.29",
        "rate": "0.9298"
    },
    "linkedCardId": "UNLINKED",
    "blockchainDepositAddress": "0x6e7A1505494Fa380D6103209883fF056BABB7412",
    "blockchainNetwork": {
        "name": "USD Coin Test (Amoy Polygon)",
        "type": "ERC20",
        "contractAddress": "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582"
    },
    "status": "ACTIVE",
    "permissions": [
        "CUSTODY",
        "TRADE",
        "INTER",
        "INTRA"
    ],
    "enriched": true,
    "parentApplicationId": "401cd14e-6680-41aa-9249-ec88059022fe",
    "syncedOwnerId": "ac69f412-efdb-4cf7-815a-13fd5bcf2a40",
    "accountPath": "7f3c6174-7a83-4270-ba8e-51cd89e0b34f:USDC",
    "blockchainNetworks": [
        {
            "name": "USD Coin Test (Solana Devnet)",
            "type": "SPL token",
            "contractAddress": "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
            "network": "SOL",
            "status": "ACCOUNT_ENRICHED",
            "blockchainDepositAddress": "4YRbV1Acdp1vXGD1fy7ohVfkXrVSfz337CkRmM5z4wSH"
        },
        {
            "name": "USD Coin Test (Sepolia)",
            "type": "ERC20",
            "contractAddress": "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
            "blockchainDepositAddress": "0x6e7A1505494Fa380D6103209883fF056BABB7412"
        },
        {
            "name": "USD Coin Test (Amoy Polygon)",
            "type": "ERC20",
            "contractAddress": "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582",
            "blockchainDepositAddress": "0x6e7A1505494Fa380D6103209883fF056BABB7412"
        }
    ],
    "multiChainSupport": true
}
```

> 🚧
>
> ### Please ensure that your users see the list of supported networks
>
> If your users deposit coins on an unsupported network, in some cases we may be able to retrieve the assets manually (Subject to a fee and our T&Cs) but in some cases there may be no possibility to recover assets. It is your responsibility to display the supported networks and the deposit address clearly to the user.
