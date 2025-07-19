---
title: Miscellaneous Webhooks
source_url: https://docs.striga.com/reference/miscellaneous-webhooks
scraped_at: 2025-07-18 17:54:18
---

# Miscellaneous Webhooks

## Account Enrichment Webhooks

Following are examples of webhooks sent when an account is successfully enriched

JSON

```
{
  "type": "ACCOUNT_ENRICHED",
  "accountId": "959d0e427d653fffc68d85bd7b45443f",
  "currency": "EUR",
  "status": "ACTIVE",
  "internalAccountId": "EUR08975982797233",
  "bankCountry": "GB",
  "bankAddress": "The Bower, 207-211 Old Street, London, England, EC1V 9NR",
  "iban": "GB84SEOU19870010076783",
  "bic": "SEOUGB21",
  "accountNumber": "010076783",
  "bankName": "Simulator Bank",
  "bankAccountHolderName": "ED ORTIZ IV ALI",
  "provider": "SIMULATOR",
  "domestic": false,
  "routingCodeEntries": [],
  "payInReference": null
}

{
  "type": "ACCOUNT_ENRICHED",
  "accountId": "930965eda2994a07b2e3dd4fc9269080",
  "currency": "1INCH",
  "blockchainDepositAddress": "0xAfC0B3BDF786e6686d68b32235f9a19FB88757cb",
  "blockchainNetwork": {
    "name": "1INCH (BSC Test)",
    "type": "BEP20",
    "contractAddress": "0x21Ee678930eDF4821C396354f3408BBd12d60DeD"
  }
}

{
  "type": "ACCOUNT_ENRICHED",
  "accountId": "b1f822b1f07bb3c30c3ceef347782971",
  "currency": "BNB",
  "blockchainDepositAddress": "0xAfC0B3BDF786e6686d68b32235f9a19FB88757cb",
  "blockchainNetwork": {
    "name": "Binance Coin Test (BSC)"
  }
}
```

## Fee Collection Webhooks

The following webhooks are sent to indicate a debit/credit event from the user account and your corporate account at Striga, whenever a fee is collected at the time of a specific transactional event, such as creating a card, a bank transfer, crypto withdrawal, swap etc.

JSON

```
{
  "type": "APPLICATION_FEE",
  "id": "148970b4-6720-4d3b-a4f6-a91bd6675365",
  "accountId": "0148ae0856b1457ff3b59f2ac965b58e",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "sourceSyncedOwnerId": "e1f5dca0-b78b-4695-8752-81b172a2ea90",
  "destinationSyncedOwnerId": "718c703a-dc08-4e80-85e1-f96003fa868b",
  "debit": "100",
  "timestamp": "2023-08-23T12:04:00.028Z",
  "txType": "APPLICATION_FEE",
  "txSubType": "THEIR_FEE",
  "memo": "Application Fee for Card Creation",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "4400",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "4300",
    "currency": "cents"
  }
}

{
  "type": "APPLICATION_FEE",
  "id": "559810dc-aab7-49d1-8738-b78249ee247f",
  "accountId": "ec7d87e7109dcc0ab6d04650762fb72f",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "debit": "4633",
  "timestamp": "2023-08-23T11:40:54.204Z",
  "txType": "APPLICATION_FEE",
  "memo": "Fee collection for 559810dc-aab7-49d1-8738-b78249ee247f",
  "exchangeRate": "23964",
  "balanceBefore": {
    "amount": "30185030",
    "currency": "satoshis"
  },
  "balanceAfter": {
    "amount": "30180397",
    "currency": "satoshis"
  },
  "isCardAuthorizationHold": false
}

{
  "type": "APPLICATION_FEE",
  "id": "722fefe9-4037-4257-b215-1e4f904b1240",
  "accountId": "0148ae0856b1457ff3b59f2ac965b58e",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "debit": "200",
  "timestamp": "2023-08-23T11:39:06.852Z",
  "txType": "APPLICATION_FEE",
  "txSubType": "THEIR_FEE",
  "memo": "Application SEPA Deposit Fee for 722fefe9-4037-4257-b215-1e4f904b1240",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "5000",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "4800",
    "currency": "cents"
  }
}

{
  "type": "APPLICATION_FEE",
  "id": "1c721c03-e34a-4073-a7ec-eab99e017f7d",
  "accountId": "0148ae0856b1457ff3b59f2ac965b58e",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "debit": "7389",
  "timestamp": "2023-08-23T11:35:04.090Z",
  "txType": "APPLICATION_FEE",
  "txSubType": "THEIR_FEE",
  "memo": "Trading Fee for 733821 EUR to BTC",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "733821",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "726432",
    "currency": "cents"
  }
}
```

## Account Creation Fee Webhooks

These webhooks are triggered during the process of enriching a USDC account on the Solana network. When enrichment is initiated, a fee is temporarily collected from the designated payer’s SOL account (either the user or your corporate account) to cover the creation of the Associated Token Account (ATA).

Once enrichment completes, if the actual on-chain cost is lower than the reserved amount (typically 0.01 SOL), a fee refund webhook is sent with the remaining balance returned to the payer’s account.

JSON

```
{
  "uid": "f79522a9-1d6f-4535-bc31-97654e882bea",
  "type": "ACCOUNT_CREATION_FEE",
  "id": "970e8a2b-d6f9-4d0f-b71c-942c6937cb40",
  "accountId": "9fa3fd8d98b494d0923de4fa75308730",
  "syncedOwnerId": "36740a7b-90a8-4e17-8b42-728d56a9de61",
  "sourceSyncedOwnerId": "36740a7b-90a8-4e17-8b42-728d56a9de61",
  "debit": "10000000",
  "timestamp": "2025-06-26T05:38:01.573Z",
  "txType": "ACCOUNT_CREATION_FEE",
  "txSubType": "ATA_CREATION_FEE",
  "memo": "Account Creation Fee SOL",
  "currency": "SOL",
  "exchangeRate": "126.17",
  "balanceBefore": {
    "amount": "394290671",
    "balance": "394290671",
    "currency": "lamports"
  },
  "balanceAfter": {
    "amount": "384290671",
    "balance": "384290671",
    "currency": "lamports"
  },
  "parentWalletId": "90aa6d97-e0ec-495c-8f39-6c6c4c491b67",
  "ts": 1750916283511
}

{
  "uid": "bd888cab-bd2b-44ff-ac45-86ffd1ec279e",
  "type": "REFUND_ACCOUNT_CREATION_FEE",
  "id": "970e8a2b-d6f9-4d0f-b71c-942c6937cb40",
  "accountId": "9fa3fd8d98b494d0923de4fa75308730",
  "syncedOwnerId": "36740a7b-90a8-4e17-8b42-728d56a9de61",
  "sourceSyncedOwnerId": "36740a7b-90a8-4e17-8b42-728d56a9de61",
  "credit": "7893847",
  "timestamp": "2025-06-26T05:38:33.429Z",
  "txType": "REFUND_ACCOUNT_CREATION_FEE",
  "txSubType": "THEIR_FEE",
  "memo": "Refund REFUND_ACCOUNT_CREATION_FEE fee of 0.007893847 SOL",
  "currency": "SOL",
  "exchangeRate": "126.17",
  "balanceBefore": {
    "amount": "384290671",
    "balance": "384290671",
    "currency": "lamports"
  },
  "balanceAfter": {
    "amount": "392184518",
    "balance": "392184518",
    "currency": "lamports"
  },
  "ts": 1750916315381
}
```

## Pending Account Enrichment Webhooks

In some cases, a webhook with the type PENDING\_ACCOUNT\_ENRICHMENT is sent to indicate that the USDC account enrichment on the Solana network is still in progress.

JSON

```
{
  "uid": "07037851-3425-446b-ac70-a54b2a9c8533",
  "type": "PENDING_ACCOUNT_ENRICHMENT",
  "accountId": "2ee07c2ac298c27603dbcdcb74fd0b5f",
  "ownerId": "36740a7b-90a8-4e17-8b42-728d56a9de61",
  "currency": "USDC",
  "blockchainDepositAddress": "0x39C6a36eCfa5904e638eCc10c2D206DAD460586D",
  "blockchainNetwork": {
    "name": "USD Coin Test (Amoy Polygon)",
    "type": "ERC20",
    "contractAddress": "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582"
  },
  "multiChainSupport": true,
  "blockchainNetworks": [
    {
      "name": "USD Coin Test (Sepolia)",
      "type": "ERC20",
      "contractAddress": "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
      "blockchainDepositAddress": "0x39C6a36eCfa5904e638eCc10c2D206DAD460586D"
    },
    {
      "name": "USD Coin Test (Amoy Polygon)",
      "type": "ERC20",
      "contractAddress": "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582",
      "blockchainDepositAddress": "0x39C6a36eCfa5904e638eCc10c2D206DAD460586D"
    },
    {
      "name": "Solana Test (Solana Devnet)",
      "network": "SOL",
      "status": "PENDING_ACCOUNT_ENRICHMENT"
    }
  ],
  "ts": 1750917849941
}
```
