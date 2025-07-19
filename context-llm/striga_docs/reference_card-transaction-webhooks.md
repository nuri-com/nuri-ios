---
title: Card Transaction Webhooks
source_url: https://docs.striga.com/reference/card-transaction-webhooks
scraped_at: 2025-07-18 17:49:50
---

# Card Transaction Webhooks

### Card Authorization Webhooks

For example, the notification below is sent when there is a **account debit transaction that corresponds to a successful card authorization.**

JSON

```
{
  "type": "CARD_AUTHORIZATION",
  "id": "cb9dfee8-9a68-4804-8ed3-5fe7204b528b",
  "accountId": "ec7d87e7109dcc0ab6d04650762fb72f",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "debit": "4193529",
  "timestamp": "2023-08-23T11:41:38.302Z",
  "txType": "CARD_AUTHORIZATION",
  "memo": "Card Authorization 0ec91933-06ef-4dd4-a558-a3edc0b26b44 of 1000 EUR at Striga Simulator",
  "exchangeRate": "23966",
  "balanceBefore": {
    "amount": "30180397",
    "currency": "satoshis"
  },
  "balanceAfter": {
    "amount": "25986868",
    "currency": "satoshis"
  },
  "relatedCardTransactionId": "cb9dfee8-9a68-4804-8ed3-5fe7204b528b",
  "isCardAuthorizationHold": true,
  "relatedCardId": "2f3fe4bd-8ad3-43bb-822e-e0c04fa8a3ac",
  "relatedCardSettlementId": "AUTHORIZATION_PENDING_CLEARING",
  "cardTransactionAmount": "1000",
  "cardTransactionCurrency": "EUR"
}
```

For example, the notification below is for a **successful card authorization.**

JSON

```
{
  "type": "CARD_AUTHORIZATION",
  "syncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
  "cardId": "2f3fe4bd-8ad3-43bb-822e-e0c04fa8a3ac",
  "parentWalletId": "e1f5dca0-b78b-4695-8752-81b172a2ea90",
  "relatedCardTransactionId": "cb9dfee8-9a68-4804-8ed3-5fe7204b528b",
  "linkedAccountId": "ec7d87e7109dcc0ab6d04650762fb72f",
  "linkedAccountCurrency": "BTC",
  "merchantTransactionAmount": "1000",
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": "1000",
  "accountTransactionCurrency": "EUR",
  "order": {
    "price": "1",
    "debit": {
      "currency": "BTC",
      "amountFloat": "0.04193529",
      "amount": "4193529"
    },
    "credit": {
      "currency": "BTC",
      "amountFloat": "0.04193529",
      "amount": "4193529"
    }
  },
  "merchantId": "Striga Simulator",
  "merchantName": "Striga Simulator",
  "merchantCity": "Tallinn",
  "merchantCountryCode": "EST",
  "merchantCategoryCode": "5812",
  "accountTransactionId": "cb9dfee8-9a68-4804-8ed3-5fe7204b528b",
  "createdAt": "2023-08-23T11:41:39.787Z",
  "originalAmount": "1000",
  "originalCurrency": "EUR",
  "transactionAmount": "1000",
  "transactionCurrency": "EUR",
  "merchantTransactionAmount": "1000",
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": "1000",
  "accountTransactionCurrency": "EUR",
  "partialPaymentSupported": false
}
```

For example, the notification below is for a **declined card authorization.**

JSON

```
{
  "type": "CARD_AUTHORIZATION_DECLINED",
  "syncedOwnerId": "b6c77114-0e07-48ec-96a8-6c7f52d07415",
  "cardId": "68f51886-83d2-4a9d-a527-35e04393384c",
  "parentWalletId": "1a6cd565-590f-4187-8d53-2f65774f9f40",
  "relatedCardTransactionId": "160f888d-5e4b-4cfc-832e-b0dbd3bf2258",
  "linkedAccountId": "8c2567601cf15786d925625cf553620d",
  "linkedAccountCurrency": "BNB",
  "merchantTransactionAmount": "10.5",
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": "10.5",
  "accountTransactionCurrency": "EUR",
  "merchantId": "Striga Simulator",
  "merchantName": "Striga Simulator",
  "merchantCity": "Tallinn",
  "merchantCountryCode": "EST",
  "merchantCategoryCode": "5812",
  "createdAt": "2023-08-21T06:18:43.905Z",
  "declineDetails": "Not Sufficient Funds",
  "originalAmount": "10.5",
  "originalCurrency": "EUR",
  "transactionAmount": "10.5",
  "transactionCurrency": "EUR",
  "partialPaymentSupported": false
}
```

For example, the notification below is for a **card authorization reversal** and it's corresponding **account credit** (A reversal means the merchant reverted the authorization and funds by default are refunded back to a users' fiat account) -

JSON

```
{
  "type": "CARD_AUTHORIZATION_REVERSAL",
  "syncedOwnerId": "f5ec617f-1b6a-452c-89be-4568b24e6f52",
  "cardId": "6c28bedd-f6d7-4030-9027-1285563a5981",
  "parentWalletId": "3772bff5-5378-42d0-8c96-d06a313da9a6",
  "relatedCardTransactionId": "d1741367-f33d-40b5-8c72-219a4a68bbef",
  "linkedAccountId": "735467bd1062f6b545476891c7e2afbe",
  "linkedAccountCurrency": "EUR",
  "merchantTransactionAmount": 0.9,
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": 0.9,
  "accountTransactionCurrency": "EUR",
  "merchantId": "E6LJ6DCBH5W3B7I",
  "merchantName": "STRIGA.COM",
  "merchantCity": "+37258986299",
  "merchantCountryCode": "EST",
  "merchantCategoryCode": "5734",
  "createdAt": "2023-06-08T08:45:27.758Z",
  "originalAmount": 0.9,
  "originalCurrency": "EUR",
  "transactionAmount": 0.9,
  "transactionCurrency": "EUR",
  "merchantTransactionAmount": "0.9",
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": "0.9",
  "accountTransactionCurrency": "EUR",
  "partialPaymentSupported": false
}
```

JSON

```
{
  "type": "CARD_AUTHORIZATION_REVERSAL",
  "id": "f6f5cf57-1816-4ce2-87ca-0b40fd691a40",
  "accountId": "735467bd1062f6b545476891c7e2afbe",
  "syncedOwnerId": "f5ec617f-1b6a-452c-89be-4568b24e6f52",
  "sourceSyncedOwnerId": "f5ec617f-1b6a-452c-89be-4568b24e6f52",
  "credit": "90",
  "timestamp": "2023-06-08T08:45:27.523Z",
  "txType": "CARD_AUTHORIZATION_REVERSAL",
  "memo": "Card Reversal for Authorisation f6f5cf57-1816-4ce2-87ca-0b40fd691a40",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "1759",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "1849",
    "currency": "cents"
  },
  "relatedCardTransactionId": "d1741367-f33d-40b5-8c72-219a4a68bbef",
  "isCardAuthorizationHold": false,
  "relatedCardId": "6c28bedd-f6d7-4030-9027-1285563a5981",
  "cardTransactionAmount": 0.9,
  "cardTransactionCurrency": "EUR"
}
```

For example, the notification below is for a **card authorization release** and it's corresponding **account credit** (A release means the merchant released the authorization request and funds by default are refunded back to a users' fiat account) -

JSON

```
{
  "type": "CARD_AUTHORIZATION_RELEASE",
  "syncedOwnerId": "5f466e20-57d4-4c91-86ac-c6a110a2360c",
  "cardId": "856f76bb-3a42-46ad-8139-66999b2b6f3d",
  "parentWalletId": "55f8e66b-1522-49f6-8765-5259ca27e57f",
  "relatedCardTransactionId": "7b6a0626-e0a4-490e-96cd-f583c684f138",
  "linkedAccountId": "b8c162051a7ea43030974c47cf28bfb2",
  "linkedAccountCurrency": "BTC",
  "merchantTransactionAmount": "1",
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": "1",
  "accountTransactionCurrency": "EUR",
  "merchantId": "000980020287994",
  "merchantName": "PAYPAL*DISNEYPLUS",
  "merchantCity": "35314369001",
  "merchantCountryCode": "NLD",
  "merchantCategoryCode": "4899",
  "createdAt": "2023-07-10T03:00:08.097Z",
  "originalAmount": "1",
  "originalCurrency": "EUR",
  "transactionAmount": "1",
  "transactionCurrency": "EUR",
  "merchantTransactionAmount": "1",
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": "1",
  "accountTransactionCurrency": "EUR"
}
```

JSON

```
{
  "type": "CARD_AUTHORIZATION_RELEASE",
  "id": "7b6a0626-e0a4-490e-96cd-f583c684f138",
  "accountId": "4dbefd8a8688bf4eca9577863272b180",
  "syncedOwnerId": "5f466e20-57d4-4c91-86ac-c6a110a2360c",
  "sourceSyncedOwnerId": "5f466e20-57d4-4c91-86ac-c6a110a2360c",
  "credit": "100",
  "timestamp": "2023-07-10T03:00:07.938Z",
  "txType": "CARD_AUTHORIZATION_RELEASE",
  "memo": "Authorization Release for Authorization 7b6a0626-e0a4-490e-96cd-f583c684f138",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "100",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "200",
    "currency": "cents"
  },
  "relatedCardTransactionId": "7b6a0626-e0a4-490e-96cd-f583c684f138",
  "isCardAuthorizationHold": false,
  "relatedCardId": "856f76bb-3a42-46ad-8139-66999b2b6f3d",
  "cardTransactionAmount": "1",
  "cardTransactionCurrency": "EUR"
}
```

When a card authorization is settled and Striga pays the scheme and merchant, you get the **settlement** webhook. A refund can occur before or after a settlement. Below are the respective card and account transaction webhooks -

JSON

```
{
  "type": "CARD_AUTHORIZATION_SETTLEMENT_CONFIRMED",
  "syncedOwnerId": "95fa9669-f423-408c-99de-f2c79ab46af9",
  "cardId": "36d910dd-396e-451b-ad5a-c1a60726f586",
  "parentWalletId": "c09f6c39-9513-4481-a490-364959ce438b",
  "relatedCardTransactionId": "da8c876a-5b26-45bb-b4f6-e74f29a30a9a",
  "linkedAccountId": "1f4e082f963262dff041de0f01f29629",
  "linkedAccountCurrency": "EUR",
  "merchantTransactionAmount": 0,
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": 0,
  "accountTransactionCurrency": "EUR",
  "merchantId": "498750000025032",
  "merchantName": "GoogleTEMPORARYHOLD",
  "merchantCity": "London",
  "merchantCountryCode": "GBR",
  "merchantCategoryCode": "7399",
  "createdAt": "2023-05-29T12:36:44.487Z",
  "originalAmount": 1,
  "originalCurrency": "EUR",
  "transactionAmount": 1,
  "transactionCurrency": "EUR",
  "merchantTransactionAmount": "1",
  "merchantTransactionCurrency": "EUR",
  "accountTransactionAmount": "1",
  "accountTransactionCurrency": "EUR"
  }
```

JSON

```
{
  "type": "CARD_AUTHORIZATION_SETTLEMENT_CONFIRMED",
  "id": "da8c876a-5b26-45bb-b4f6-e74f29a30a9a",
  "accountId": "1f4e082f963262dff041de0f01f29629",
  "syncedOwnerId": "95fa9669-f423-408c-99de-f2c79ab46af9",
  "sourceSyncedOwnerId": "95fa9669-f423-408c-99de-f2c79ab46af9",
  "timestamp": "2023-05-29T12:36:44.276Z",
  "txType": "CARD_AUTHORIZATION_SETTLEMENT_CONFIRMED",
  "memo": "Card Settlement for Authorization da8c876a-5b26-45bb-b4f6-e74f29a30a9a",
  "exchangeRate": "1",
  "balanceBefore": {
    "amount": "2",
    "currency": "cents"
  },
  "balanceAfter": {
    "amount": "2",
    "currency": "cents"
  },
  "isCardAuthorizationHold": false,
  "relatedCardId": "36d910dd-396e-451b-ad5a-c1a60726f586",
  "relatedCardSettlementId": null,
  "cardTransactionAmount": "0",
  "cardTransactionCurrency": "EUR"
  }
```
