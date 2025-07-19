---
title: Bank Transfer Webhooks
source_url: https://docs.striga.com/reference/bank-transfer-webhooks
scraped_at: 2025-07-18 17:54:50
---

# Bank Transfer Webhooks

### SEPA Transaction Webhooks

For example, the notification below is sent for a **successful SEPA deposit** to an enriched account

JSON

```
{
  "type": "SEPA_PAYIN_COMPLETED",
  "id": "ad8b61cf-ea28-4f2f-a0ee-170b47d3d136",
  "accountId": "0148ae0856b1457ff3b59f2ac965b58e",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "credit": "500",
  "timestamp": "2023-08-22T09:05:53.615Z",
  "txType": "SEPA_PAYIN_COMPLETED",
  "memo": "Simulate Payin",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "979900",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "980400",
    "currency": "cents"
  },
  "bankingTransactionId": "ad8b61cf-ea28-4f2f-a0ee-170b47d3d136",
  "bankingTransactionShortId": "20230822-V4SD5L",
  "bankingSenderBic": "BUKBGB22",
  "bankingSenderIban": "GB29NWBK60161331926819",
  "bankingSenderName": "Boris Johnson",
  "bankingPaymentType": "SEPA",
  "bankingSenderInformation": null,
  "bankingSenderRoutingCodes": [],
  "bankingSenderAccountNumber": null,
  "bankingTransactionDateTime": "2023-08-22T09:05:52.860121",
  "bankingTransactionReference": "Simulate Payin"
}
```

For example, the notification below is sent when a **SEPA payout is initiated** from an enriched account

JSON

```
{
  "type": "SEPA_PAYOUT_INITIATED",
  "id": "60c12078-456f-460a-8cbe-8657edd9b3e2",
  "syncedOwnerId": "eda728dc-ed0f-48d9-8d81-57dbdc669a46",
  "credit": 0,
  "debit": 100,
  "timestamp": "2022-08-29T10:09:12.207Z",
  "txType": "SEPA_PAYOUT_INITIATED",
  "nonFpFeeBaseCurrency": 0,
  "feeEur": 0,
  "exchangeRate": 1,
  "balanceBefore": {
    "amount": 200000,
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": 199900,
    "currency": "cents"
  },
  "bankingTransactionShortId": "20220829-C9WRON",
  "bankingSenderBic": "SEOUGB21",
  "bankingSenderIban": "GB23SEOU19870010045677",
  "bankingSenderName": "Herta Frances Bruen",
  "bankingPaymentType": "SEPA",
  "bankingTransactionReference": "whiteboard vortals compelling-FYelJ8mbUa",
  "bankingBeneficiaryBic": "EVIULT2VXXX",
  "bankingBeneficiaryIban": "LT483500010015291122"
}
```

For example, the notification below is sent when a **SEPA payout is completed**

JSON

```
{
  "type": "SEPA_PAYOUT_COMPLETED",
  "id": "60c12078-456f-460a-8cbe-8657edd9b3e2",
  "syncedOwnerId": "eda728dc-ed0f-48d9-8d81-57dbdc669a46",
  "credit": 0,
  "debit": 0,
  "timestamp": "2022-08-29T10:09:25.907Z",
  "txType": "SEPA_PAYOUT_COMPLETED",
  "nonFpFeeBaseCurrency": 0,
  "feeEur": 0,
  "exchangeRate": 1,
  "balanceBefore": {
    "amount": 199900,
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": 199900,
    "currency": "cents"
  },
  "bankingTransactionShortId": "20220829-C9WRON",
  "bankingPaymentType": "SEPA",
  "bankingTransactionDateTime": "2022-08-29T10:09:25.421Z",
  "bankingTransactionReference": "whiteboard vortals compelling-FYelJ8mbUa"
}
```

For example, the notification below is sent when a **SEPA payout fails**

JSON

```
{
    "type": "SEPA_PAYOUT_FAILED",
    "id": "6c92c163-938b-4984-9152-d2377bc4d8fb",
    "accountId": "c667bd515ad34f1ef53c2d4b253dc51c",
    "syncedOwnerId": "2d2a36f3-4518-4e59-954a-a3660c7facfa",
    "sourceSyncedOwnerId": "2d2a36f3-4518-4e59-954a-a3660c7facfa",
    "credit": "40120",
    "timestamp": "2023-08-31T10:16:28.774Z",
    "txType": "SEPA_PAYOUT_FAILED",
    "memo": "vEDXfwo5ij",
    "exchangeRate": "1",
    "balanceBefore": {
      "amount": "0",
      "currency": "cents"
    },
    "balanceAfter": {
      "amount": "40120",
      "currency": "cents"
    },
    "bankingTransactionShortId": "20230831-3L2H3W",
    "bankingPaymentType": "SEPA",
    "bankingTransactionDateTime": "2023-08-31T10:16:28.355Z",
    "bankingTransactionReference": "vEDXfwo5ij"
  }

{
  "type": "SEPA_PAYOUT_DENIED",
  "id": "345c58d7-4f83-4fe1-afd2-24960a5b1e8e",
  "accountId": "751c8914b0ff59a0642284ece25ad798",
  "syncedOwnerId": "4a3ad895-8347-4b45-b0ee-4d24b5f76f35",
  "sourceSyncedOwnerId": "4a3ad895-8347-4b45-b0ee-4d24b5f76f35",
  "credit": "22",
  "timestamp": "2023-01-03T12:05:20.112Z",
  "txType": "SEPA_PAYOUT_DENIED",
  "memo": "SEPA_PAYOUT_INITIATED_LFhEtNYpKI",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "10074526",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "10074548",
    "currency": "cents"
  },
  "bankingTransactionShortId": null,
  "bankingSenderBic": "SEOUGB21",
  "bankingSenderIban": "GB58SEOU19870010070849",
  "bankingSenderName": "Lenny Randy Treutel",
  "bankingPaymentType": null,
  "bankingTransactionReference": null,
  "bankingBeneficiaryBic": null,
  "bankingBeneficiaryIban": null
}
```
