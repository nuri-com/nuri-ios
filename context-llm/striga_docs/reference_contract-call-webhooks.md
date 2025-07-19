---
title: Contract Call Webhooks
source_url: https://docs.striga.com/reference/contract-call-webhooks
scraped_at: 2025-07-18 17:50:00
---

# Contract Call Webhooks

### Contract Call Webhooks

The following webhooks are sent when a contract call is successfully initiated and a transaction hash is created, followed by your account balance being updated based on the network fee that was paid to execute this transaction -

JSON

```
{
  "type": "CONTRACT_CALL_PENDING",
  "id": "011b9488-819b-495f-b178-387b6486e25b",
  "syncedOwnerId": "c3284841-7848-4017-a1b9-bf5c3e4dad2e",
  "credit": 0,
  "debit": "0",
  "timestamp": "2022-11-28T09:36:10.406Z",
  "txType": "CONTRACT_CALL_PENDING",
  "balanceBefore": {
    "amount": "39717272096031940",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "39717272096031940",
    "currency": "wei"
  },
  "blockchainSourceAddress": "",
  "txHash": "0xb5bf43bab636084e2f7956040bace3525243eddbda297db010cd58ac1513591c",
  "blockchainDepositAddress": "0x93CD6a01A55805A3af582893f2D04051ea47f61D",
  "blockchainConfirmations": 0,
  "blockchainTransactionAmount": "0"
}
```

JSON

```
{
  "type": "CONTRACT_CALL_NETWORK_FEE",
  "id": "011b9488-819b-495f-b178-387b6486e25b",
  "syncedOwnerId": "c3284841-7848-4017-a1b9-bf5c3e4dad2e",
  "credit": 0,
  "debit": "3374767813202115",
  "timestamp": "2022-11-28T09:36:10.960Z",
  "txType": "CONTRACT_CALL_NETWORK_FEE",
  "txSubType": "TOTAL_FEE",
  "balanceBefore": {
    "amount": "39717272096031940",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "36342504282829825",
    "currency": "wei"
  },
  "blockchainSourceAddress": "",
  "txHash": "0xb5bf43bab636084e2f7956040bace3525243eddbda297db010cd58ac1513591c",
  "blockchainDepositAddress": "0x93CD6a01A55805A3af582893f2D04051ea47f61D",
  "blockchainConfirmations": 0,
  "blockchainTransactionAmount": "0"
}
```

The following webhook is sent when a contract call is successfully initiated and a transaction is confirmed -

JSON

```
{
  "type": "CONTRACT_CALL_CONFIRMED",
  "id": "011b9488-819b-495f-b178-387b6486e25b",
  "syncedOwnerId": "c3284841-7848-4017-a1b9-bf5c3e4dad2e",
  "credit": 0,
  "debit": "0",
  "timestamp": "2022-11-28T09:37:11.870Z",
  "txType": "CONTRACT_CALL_CONFIRMED",
  "balanceBefore": {
    "amount": "32967736469627710",
    "currency": "wei"
  },
  "balanceAfter": {
    "amount": "32967736469627710",
    "currency": "wei"
  },
  "blockchainSourceAddress": "",
  "txHash": "0xb5bf43bab636084e2f7956040bace3525243eddbda297db010cd58ac1513591c",
  "blockchainDepositAddress": "0x93CD6a01A55805A3af582893f2D04051ea47f61D",
  "blockchainConfirmations": 3,
  "blockchainTransactionAmount": "0"
}
```
