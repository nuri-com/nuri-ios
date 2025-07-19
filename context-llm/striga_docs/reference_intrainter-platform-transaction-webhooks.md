---
title: Intra/Inter Platform Transaction Webhooks
source_url: https://docs.striga.com/reference/intrainter-platform-transaction-webhooks
scraped_at: 2025-07-18 17:53:54
---

# Intra/Inter Platform Transaction Webhooks

### Inter/Intra Ledger Webhooks

For example, the notification below is for a **successful inter/intra transaction** between two accounts on your own application

JSON

```
{
  "type": "INTRA_LEDGER_SEND",
  "id": "8018e69e-cb3c-465d-b05b-7eaf82f5cfcc",
  "accountId": "0148ae0856b1457ff3b59f2ac965b58e",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "destinationSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "debit": "100000",
  "timestamp": "2023-08-22T14:24:24.099Z",
  "txType": "INTRA_LEDGER_SEND",
  "memo": "Intraledger 0148ae0856b1457ff3b59f2ac965b58e to e38378c7ead5b4a2506984fad80257bb",
  "memoPayer": "grow impactful deliverables",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "459696",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "359696",
    "currency": "cents"
  }
}

{
  "type": "INTER_LEDGER_SEND",
  "id": "90936049-a3a0-4ca8-8fb2-6c4ae93ae717",
  "accountId": "5ad9f70b933ca275fee8de8ca684002d",
  "syncedOwnerId": "2d57625c-cd8c-4949-a380-326711b04337",
  "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "destinationSyncedOwnerId": "2d57625c-cd8c-4949-a380-326711b04337",
  "credit": "500",
  "timestamp": "2023-08-23T11:31:26.573Z",
  "txType": "INTER_LEDGER_SEND",
  "memo": "Interledger 5 EUR to EUR",
  "memoPayer": "extend",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "118318",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "118818",
    "currency": "cents"
  }
}
```
