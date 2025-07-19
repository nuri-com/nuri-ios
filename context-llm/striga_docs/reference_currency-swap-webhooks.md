---
title: Currency Swap Webhooks
source_url: https://docs.striga.com/reference/currency-swap-webhooks
scraped_at: 2025-07-18 17:55:03
---

# Currency Swap Webhooks

## Currency Swap Webhooks

The following webhook is sent when a currency swap is initiated through the API

JSON

```
{
  "type": "CURRENCY_EXCHANGE",
  "id": "ed0e9c23-2090-4562-80aa-aa68ad22cd4d",
  "accountId": "e6c61a6e7d4436ef9086a4a214e4c880",
  "syncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "sourceSyncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "destinationSyncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "debit": "9700",
  "timestamp": "2024-04-17T11:44:46.378Z",
  "txType": "EXCHANGE_DEBIT",
  "txSubType": "CURRENCY_EXCHANGE_PENDING",
  "memo": "Swap 97 EUR to USDT",
  "memoPayer": "Striga",
  "currency": "EUR",
  "exchangeRate": "1",
  "order": {
    "price": "0.96",
    "debit": {
      "currency": "EUR",
      "amountFloat": "97",
      "amount": "9700"
    },
    "credit": {
      "currency": "USDT",
      "amountFloat": "101.04",
      "amount": "10104"
    }
  },
  "balanceBefore": {
    "amount": "99526",
    "balance": "99526",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "89826",
    "balance": "89826",
    "currency": "cents"
  },
  "feeEstimate": {
    "totalFee": "300",
    "networkFee": "0",
    "ourFee": "0",
    "theirFee": "300",
    "feeCurrency": "EUR",
    "fixedFeeDetails": {
      "amount": "100",
      "exchangeRate": "1",
      "appliedFeeCents": "100"
    },
    "percentageFeeDetails": {
      "amount": "200",
      "appliedFeeBps": "200"
    }
  }
}
```

The following webhook is sent when the currency swap has been successfully completed and the funds have been transferred

JSON

```
{
  "type": "CURRENCY_EXCHANGE",
  "id": "ed0e9c23-2090-4562-80aa-aa68ad22cd4d",
  "accountId": "df4b4ff09a9356230658fce74a7d7e79",
  "syncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "sourceSyncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "destinationSyncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "credit": "10104",
  "timestamp": "2024-04-17T11:44:48.708Z",
  "txType": "EXCHANGE_CREDIT",
  "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
  "memo": "Swap 97 EUR to USDT",
  "memoPayer": "Striga",
  "currency": "USDT",
  "exchangeRate": "1",
  "order": {
    "price": "0.96",
    "debit": {
      "currency": "EUR",
      "amountFloat": "97",
      "amount": "9700"
    },
    "credit": {
      "currency": "USDT",
      "amountFloat": "101.04",
      "amount": "10104"
    }
  },
  "balanceBefore": {
    "amount": "0",
    "balance": "0",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "10104",
    "balance": "10104",
    "currency": "cents"
  },
  "feeEstimate": {
    "totalFee": "300",
    "networkFee": "0",
    "ourFee": "0",
    "theirFee": "300",
    "feeCurrency": "EUR",
    "fixedFeeDetails": {
      "amount": "100",
      "exchangeRate": "1",
      "appliedFeeCents": "100"
    },
    "percentageFeeDetails": {
      "amount": "200",
      "appliedFeeBps": "200"
    }
  }
}
```

The following webhook is sent when the currency swap fails and a refund is initiated

JSON

```
{
  "type": "CURRENCY_EXCHANGE",
  "id": "e1f92312-1841-4588-940d-f9f47a7379a1",
  "accountId": "e6c61a6e7d4436ef9086a4a214e4c880",
  "syncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "sourceSyncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "destinationSyncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "credit": "9700",
  "timestamp": "2024-04-17T11:50:50.809Z",
  "txType": "EXCHANGE_CREDIT",
  "txSubType": "CURRENCY_EXCHANGE_REFUND",
  "memo": "Failed Swap 97 EUR to USDC",
  "memoPayer": "mesh web-enabled relationships",
  "currency": "EUR",
  "exchangeRate": "1",
  "order": {},
  "balanceBefore": {
    "amount": "80126",
    "balance": "80126",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "89826",
    "balance": "89826",
    "currency": "cents"
  },
  "feeEstimate": {
    "totalFee": "300",
    "networkFee": "0",
    "ourFee": "0",
    "theirFee": "300",
    "feeCurrency": "EUR",
    "fixedFeeDetails": {
      "amount": "100",
      "exchangeRate": "1",
      "appliedFeeCents": "100"
    },
    "percentageFeeDetails": {
      "amount": "200",
      "appliedFeeBps": "200"
    }
  }
}
```

The following webhook is sent when the swap endpoint is used for moving funds in the same currency between two wallets of the same user, one for the destination and one for the source account. Please note, the type here is `INTRA_LEDGER_SEND` as no swap is executed for moving funds in the same currency

JSON

```
{
  "type": "INTRA_LEDGER_SEND",
  "id": "6c08edfe-c07d-4ac1-9fee-4c48577a5384",
  "accountId": "d1c302e46e0901ffe427229df54c1001",
  "syncedOwnerId": "b9556e1f-e1c4-46f9-9809-c3706116e751",
  "sourceSyncedOwnerId": "b9556e1f-e1c4-46f9-9809-c3706116e751",
  "destinationSyncedOwnerId": "b9556e1f-e1c4-46f9-9809-c3706116e751",
  "credit": "44",
  "timestamp": "2023-05-11T08:55:36.454Z",
  "txType": "INTRA_LEDGER_SEND",
  "memo": "Intraledger 387c965efc64e066415c5e45897ab94f to d1c302e46e0901ffe427229df54c1001",
  "memoPayer": "DEMO",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "512",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "556",
    "currency": "cents"
  }
}

{
  "type": "INTRA_LEDGER_SEND",
  "id": "6c08edfe-c07d-4ac1-9fee-4c48577a5384",
  "accountId": "387c965efc64e066415c5e45897ab94f",
  "syncedOwnerId": "b9556e1f-e1c4-46f9-9809-c3706116e751",
  "sourceSyncedOwnerId": "b9556e1f-e1c4-46f9-9809-c3706116e751",
  "destinationSyncedOwnerId": "b9556e1f-e1c4-46f9-9809-c3706116e751",
  "debit": "44",
  "timestamp": "2023-05-11T08:55:36.454Z",
  "txType": "INTRA_LEDGER_SEND",
  "memo": "Intraledger 387c965efc64e066415c5e45897ab94f to d1c302e46e0901ffe427229df54c1001",
  "memoPayer": "DEMO",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "997370",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "997326",
    "currency": "cents"
  }
}
```

## Swap Fee Collection Webhooks

When you configure your application to collect fees when making a swap, the following webhook is sent after a successful swap

JSON

```
{
  "type": "APPLICATION_FEE",
  "id": "ed0e9c23-2090-4562-80aa-aa68ad22cd4d",
  "accountId": "ed36d7ff9bc685e6adc807d92815ccc9",
  "syncedOwnerId": "22af0bb2-3009-4976-9b34-b7a89fc33a30",
  "sourceSyncedOwnerId": "2fb78ff7-6d3b-4bf6-aff9-bb50e8c94141",
  "credit": "300",
  "timestamp": "2024-04-17T11:44:51.471Z",
  "txType": "APPLICATION_FEE",
  "txSubType": "THEIR_FEE",
  "memo": "Application Swap Fee for ed0e9c23-2090-4562-80aa-aa68ad22cd4d EUR to USDT",
  "currency": "EUR",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "23648",
    "balance": "23648",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "23948",
    "balance": "23948",
    "currency": "cents"
  },
  "feeEstimate": {
    "totalFee": "300",
    "networkFee": "0",
    "ourFee": "0",
    "theirFee": "300",
    "feeCurrency": "EUR",
    "fixedFeeDetails": {
      "amount": "100",
      "exchangeRate": "1",
      "appliedFeeCents": "100"
    },
    "percentageFeeDetails": {
      "amount": "200",
      "appliedFeeBps": "200"
    }
  }
}
```
