---
title: Crypto Deposit/Withdrawal Webhooks
source_url: https://docs.striga.com/reference/crypto-depositwithdrawal-webhooks
scraped_at: 2025-07-18 17:52:41
---

# Crypto Deposit/Withdrawal Webhooks

### Blockchain Transaction Webhooks

For example, the notification below is sent for a **pending blockchain transaction** to an enriched crypto account

JSON

```
{
  "type": "ON_CHAIN_DEPOSIT_PENDING",
  "id": "deaabb1b-50ec-4f2c-b30b-889d03826b64",
  "accountId": "d89e36dbd64da96f67e36c4b564320db",
  "syncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "sourceSyncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "timestamp": "2024-09-10T12:05:39.448Z",
  "txType": "ON_CHAIN_DEPOSIT_PENDING",
  "memo": "0.2 POL PENDING_BLOCKCHAIN_CONFIRMATIONS 0x7dc24b5316767f4269bbba3e9fb01a4af8af14d5e46e867d47dde3055cbbb262",
  "currency": "POL",
  "exchangeRate": "0.35",
  "balanceBefore": {
    "amount": "0",
    "balance": "0",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "0",
    "balance": "0",
    "currency": "wei"
  },
  "blockchainSourceAddress": "0x54d03EC0C462e9a01F77579C090cdE0FC2617817",
  "txHash": "0x7dc24b5316767f4269bbba3e9fb01a4af8af14d5e46e867d47dde3055cbbb262",
  "blockchainDepositAddress": "0xd9f344019a5f2f26755f02a41548b4310be8F8fE",
  "blockchainConfirmations": 1,
  "blockchainTransactionAmount": "200000000000000000",
  "blockchainNetwork": "Polygon Testnet Amoy"
}
```

For example, the notification below is sent for a **confirmed blockchain transaction** to an enriched crypto account

JSON

```
{
  "type": "ON_CHAIN_DEPOSIT_CONFIRMED",
  "id": "deaabb1b-50ec-4f2c-b30b-889d03826b64",
  "accountId": "d89e36dbd64da96f67e36c4b564320db",
  "syncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "sourceSyncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "credit": "200000000000000000",
  "timestamp": "2024-09-10T12:05:40.606Z",
  "txType": "ON_CHAIN_DEPOSIT_CONFIRMED",
  "memo": "0.2 POL CONFIRMED 0x7dc24b5316767f4269bbba3e9fb01a4af8af14d5e46e867d47dde3055cbbb262",
  "currency": "POL",
  "exchangeRate": "0.35",
  "balanceBefore": {
    "amount": "0",
    "balance": "0",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "200000000000000000",
    "balance": "200000000000000000",
    "currency": "wei"
  },
  "blockchainSourceAddress": "0x54d03EC0C462e9a01F77579C090cdE0FC2617817",
  "txHash": "0x7dc24b5316767f4269bbba3e9fb01a4af8af14d5e46e867d47dde3055cbbb262",
  "blockchainDepositAddress": "0xd9f344019a5f2f26755f02a41548b4310be8F8fE",
  "blockchainConfirmations": 1,
  "blockchainTransactionAmount": "200000000000000000",
  "blockchainNetwork": "Polygon Testnet Amoy"
}
```

### On Chain Withdrawal Webhooks

The following webhook is sent for an on chain withdrawal that has been initiated -

JSON

```
{
  "type": "ON_CHAIN_WITHDRAWAL_INITIATED",
  "id": "d646143f-85af-4197-88ac-a84e46002205",
  "accountId": "244337fcf5b13ff40f7780bdd3e66d30",
  "syncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "sourceSyncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "debit": "9363699999622000",
  "timestamp": "2024-09-10T12:09:45.657Z",
  "txType": "ON_CHAIN_WITHDRAWAL_INITIATED",
  "memo": "ON_CHAIN_WITHDRAWAL_INITIATED 0.009363699999622 POL d646143f-85af-4197-88ac-a84e46002205",
  "currency": "POL",
  "exchangeRate": "0.35",
  "balanceBefore": {
    "amount": "119078888888888888887",
    "balance": "119078888888888888887",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "119069525188889266887",
    "balance": "119069525188889266887",
    "currency": "wei"
  },
  "feeEstimate": {
    "totalFee": "636300000378000",
    "networkFee": "636300000378000",
    "ourFee": "636300000378000",
    "theirFee": "0",
    "feeCurrency": "POL",
    "gasLimit": "21000",
    "gasPrice": "30.3",
    "fixedFeeDetails": {
      "amount": "0",
      "exchangeRate": "0"
    },
    "percentageFeeDetails": {
      "amount": "0"
    }
  },
  "blockchainNetwork": "Polygon Testnet Amoy"
}
```

The following webhook is sent for an on chain withdrawal that is pending -

JSON

```
{
 "type": "ON_CHAIN_WITHDRAWAL_PENDING",
  "id": "d646143f-85af-4197-88ac-a84e46002205",
  "accountId": "244337fcf5b13ff40f7780bdd3e66d30",
  "syncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "sourceSyncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "timestamp": "2024-09-10T12:09:58.050Z",
  "txType": "ON_CHAIN_WITHDRAWAL_PENDING",
  "memo": "POL ON_CHAIN_WITHDRAWAL_PENDING BROADCASTING",
  "currency": "POL",
  "exchangeRate": "0.35",
  "balanceBefore": {
    "amount": "119068888888888888887",
    "balance": "119068888888888888887",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "119068888888888888887",
    "balance": "119068888888888888887",
    "currency": "wei"
  },
  "blockchainSourceAddress": "",
  "txHash": "0xebaa3406cb669c975b31fb0b5fa384aefe95250e882a7e55a7a3f3b2f9c230cc",
  "blockchainDepositAddress": "0xd1257B051c3CB9d26A7f3b2073b542241dE470b1",
  "blockchainConfirmations": 0,
  "feeEstimate": {
    "totalFee": "636300000378000",
    "networkFee": "636300000378000",
    "ourFee": "636300000378000",
    "theirFee": "0",
    "feeCurrency": "POL",
    "gasLimit": "21000",
    "gasPrice": "30.3",
    "fixedFeeDetails": {
      "amount": "0",
      "exchangeRate": "0"
    },
    "percentageFeeDetails": {
      "amount": "0"
    }
  },
  "blockchainNetwork": "Polygon Testnet Amoy"
}
```

The following webhook is sent for an on chain withdrawal that has been completed -

JSON

```
{
  "type": "ON_CHAIN_WITHDRAWAL_CONFIRMED",
  "id": "d646143f-85af-4197-88ac-a84e46002205",
  "accountId": "244337fcf5b13ff40f7780bdd3e66d30",
  "syncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "sourceSyncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "timestamp": "2024-09-10T12:10:19.628Z",
  "txType": "ON_CHAIN_WITHDRAWAL_CONFIRMED",
  "memo": "POL ON_CHAIN_WITHDRAWAL_CONFIRMED COMPLETED",
  "currency": "POL",
  "exchangeRate": "0.35",
  "balanceBefore": {
    "amount": "119068888888888888887",
    "balance": "119068888888888888887",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "119068888888888888887",
    "balance": "119068888888888888887",
    "currency": "wei"
  },
  "blockchainSourceAddress": "0x606baDb2A7145FFC443575635Bb07fd23AE14478",
  "txHash": "0xebaa3406cb669c975b31fb0b5fa384aefe95250e882a7e55a7a3f3b2f9c230cc",
  "blockchainDepositAddress": "0xd1257B051c3CB9d26A7f3b2073b542241dE470b1",
  "blockchainConfirmations": 1,
  "feeEstimate": {
    "totalFee": "636300000378000",
    "networkFee": "636300000378000",
    "ourFee": "636300000378000",
    "theirFee": "0",
    "feeCurrency": "POL",
    "gasLimit": "21000",
    "gasPrice": "30.3",
    "fixedFeeDetails": {
      "amount": "0",
      "exchangeRate": "0"
    },
    "percentageFeeDetails": {
      "amount": "0"
    }
  },
  "blockchainNetwork": "Polygon Testnet Amoy"
}
```

The following webhook is sent for the fees collected from a user on your behalf for on chain withdrawals, and credited to your account -

JSON

```
{
  "type": "APPLICATION_FEE",
  "id": "20a7cc2a-98d9-458d-b8ac-c390b1418609",
  "accountId": "56f839fa6bf58216b64a9070d11b2eac",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "debit": "50",
  "timestamp": "2023-08-31T09:34:06.109Z",
  "txType": "APPLICATION_FEE",
  "txSubType": "THEIR_FEE",
  "memo": "Application VA Withdrawal fee for 20a7cc2a-98d9-458d-b8ac-c390b1418609",
  "exchangeRate": "0.92",
  "balanceBefore": {
    "amount": "4843",
    "balance": "4843",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "4793",
    "balance": "4793",
    "currency": "cents"
  }
}

{
  "type": "APPLICATION_FEE",
  "id": "20a7cc2a-98d9-458d-b8ac-c390b1418609",
  "accountId": "ec080168771a370bc89478b42e229549",
  "syncedOwnerId": "2d57625c-cd8c-4949-a380-326711b04337",
  "sourceSyncedOwnerId": "StrigaFeeHoldAccount",
  "destinationSyncedOwnerId": "718c703a-dc08-4e80-85e1-f96003fa868b",
  "credit": "50",
  "timestamp": "2023-08-31T09:35:07.537Z",
  "txType": "APPLICATION_FEE",
  "txSubType": "THEIR_FEE",
  "memo": "Application VA Withdrawal fee for 20a7cc2a-98d9-458d-b8ac-c390b1418609",
  "exchangeRate": "0.92",
  "balanceBefore": {
    "amount": "207",
    "balance": "207",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "257",
    "balance": "257",
    "currency": "cents"
  }
}
```

The following webhook is sent for the fees collected from a user after an on chain withdrawal has been initiated, to pay for network fees -

JSON

```
{
  "type": "NETWORK_FEE",
  "id": "d646143f-85af-4197-88ac-a84e46002205",
  "accountId": "244337fcf5b13ff40f7780bdd3e66d30",
  "syncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "sourceSyncedOwnerId": "104894c7-95fc-4dde-97dd-cb25b2587b91",
  "debit": "636300000378000",
  "timestamp": "2024-09-10T12:09:46.293Z",
  "txType": "NETWORK_FEE",
  "txSubType": "TOTAL_WITHDRAWAL_FEE",
  "memo": "NETWORK_FEE of 0.000636300000378 POL d646143f-85af-4197-88ac-a84e46002205",
  "currency": "POL",
  "exchangeRate": "0.35",
  "balanceBefore": {
    "amount": "119069525188889266887",
    "balance": "119069525188889266887",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "119068888888888888887",
    "balance": "119068888888888888887",
    "currency": "wei"
  },
  "feeEstimate": {
    "totalFee": "636300000378000",
    "networkFee": "636300000378000",
    "ourFee": "636300000378000",
    "theirFee": "0",
    "feeCurrency": "POL",
    "gasLimit": "21000",
    "gasPrice": "30.3",
    "fixedFeeDetails": {
      "amount": "0",
      "exchangeRate": "0"
    },
    "percentageFeeDetails": {
      "amount": "0"
    }
  },
  "blockchainNetwork": "Polygon Testnet Amoy"
}
```

The following webhook is sent when funds and the corresponding fees are refunded when an on chain withdrawal fails

JSON

```
{
  "type": "ON_CHAIN_WITHDRAWAL_FAILED",
  "id": "ee9e8733-3e1a-4ced-9bb3-7600b64d2a69",
  "accountId": "7cb14c21eb7283745ba629d5dc8e6c7d",
  "syncedOwnerId": "50febc83-6118-419e-82e1-886f8c7ffd59",
  "credit": "22310983910888449318",
  "timestamp": "2022-11-30T16:21:15.187Z",
  "txType": "ON_CHAIN_WITHDRAWAL_FAILED",
  "memo": "BNB_TEST_FAILED",
  "balanceBefore": {
    "amount": "1144927556020485960",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "3376025947109330892752",
    "currency": "wei"
  },
  "blockchainSourceAddress": "",
  "txHash": "",
  "blockchainDepositAddress": "",
  "blockchainConfirmations": null
}

{
  "type": "FEE_REFUND",
  "id": "ee9e8733-3e1a-4ced-9bb3-7600b64d2a69",
  "accountId": "7cb14c21eb7283745ba629d5dc8e6c7d",
  "syncedOwnerId": "50febc83-6118-419e-82e1-886f8c7ffd59",
  "credit": "22536559696857019513",
  "timestamp": "2022-11-30T16:21:15.441Z",
  "txType": "FEE_REFUND",
  "txSubType": "TOTAL_WITHDRAWAL_FEE",
  "memo": "BNB_TEST_FAILED",
  "balanceBefore": {
    "amount": "3376025947109330892752",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "3398562506806187912265",
    "currency": "wei"
  },
  "blockchainSourceAddress": "",
  "txHash": "",
  "blockchainDepositAddress": "",
  "blockchainConfirmations": null
}
```
