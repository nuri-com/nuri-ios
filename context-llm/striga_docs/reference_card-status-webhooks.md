---
title: Card Status Webhooks
source_url: https://docs.striga.com/reference/card-status-webhooks
scraped_at: 2025-07-18 17:52:04
---

# Card Status Webhooks

## Card Expired Webhooks

Following are examples of webhooks sent when the card is expired

JSON

```
{
  "name": "Satoshi Nakamoto",
  "id": "8e1e8f4c-b492-4071-8536-a0c52bce7c7d",
  "type": "VIRTUAL",
  "userId": "6890d93e-9b0f-4448-a2eb-270263edc7b7",
  "maskedCardNumber": "437512******5115",
  "expiryData": "2023-12-31T23:59:59Z",
  "expiryDate": "2023-12-31T23:59:59Z",
  "status": "EXPIRED",
  "isEnrolledFor3dSecure": true,
  "isCard3dSecureActivated": true,
  "security": {
    "contactlessEnabled": true,
    "withdrawalEnabled": true,
    "internetPurchaseEnabled": true,
    "overallLimitsEnabled": true
  },
  "limits": {
    "dailyPurchase": 10000,
    "dailyWithdrawal": 350,
    "dailyInternetPurchase": 10000,
    "dailyContactlessPurchase": 10000,
    "weeklyPurchase": 15000,
    "weeklyWithdrawal": 3000,
    "weeklyInternetPurchase": 15000,
    "weeklyContactlessPurchase": 15000,
    "monthlyPurchase": 15000,
    "monthlyWithdrawal": 3000,
    "monthlyInternetPurchase": 15000,
    "monthlyContactlessPurchase": 15000,
    "transactionPurchase": 10000,
    "transactionWithdrawal": 350,
    "transactionInternetPurchase": 10000,
    "transactionContactlessPurchase": 50,
    "dailyOverallPurchase": 10000,
    "weeklyOverallPurchase": 10000,
    "monthlyOverallPurchase": 10000,
    "dailyContactlessPurchaseAvailable": 10000,
    "dailyContactlessPurchaseUsed": 0,
    "dailyInternetPurchaseAvailable": 10000,
    "dailyInternetPurchaseUsed": 0,
    "dailyOverallPurchaseAvailable": 10000,
    "dailyOverallPurchaseUsed": 0,
    "dailyPurchaseAvailable": 10000,
    "dailyPurchaseUsed": 0,
    "dailyWithdrawalAvailable": 350,
    "dailyWithdrawalUsed": 0,
    "monthlyContactlessPurchaseAvailable": 15000,
    "monthlyContactlessPurchaseUsed": 0,
    "monthlyInternetPurchaseAvailable": 15000,
    "monthlyInternetPurchaseUsed": 0,
    "monthlyOverallPurchaseAvailable": 10000,
    "monthlyOverallPurchaseUsed": 0,
    "monthlyPurchaseAvailable": 15000,
    "monthlyPurchaseUsed": 0,
    "monthlyWithdrawalAvailable": 3000,
    "monthlyWithdrawalUsed": 0,
    "weeklyContactlessPurchaseAvailable": 15000,
    "weeklyContactlessPurchaseUsed": 0,
    "weeklyInternetPurchaseAvailable": 15000,
    "weeklyInternetPurchaseUsed": 0,
    "weeklyOverallPurchaseAvailable": 10000,
    "weeklyOverallPurchaseUsed": 0,
    "weeklyPurchaseAvailable": 15000,
    "weeklyPurchaseUsed": 0,
    "weeklyWithdrawalAvailable": 3000,
    "weeklyWithdrawalUsed": 0
  },
  "activatedAt": "2023-11-01T12:18:51Z",
  "linkedAccountId": "22eb9caee08de8410eb0b41c5afd249e",
  "parentWalletId": "a82afcee-6b53-4869-a41a-df34e6b228db",
  "linkedAccountCurrency": "EUR",
  "createdAt": "2023-11-01T12:18:51Z"
}

```

## Card Closed Webhooks

Following are examples of webhooks sent when the card is closed

JSON

```
{
  "name": "Satoshi Nakamoto",
  "id": "8e1e8f4c-b492-4071-8536-a0c52bce7c7d",
  "type": "PHYSICAL",
  "userId": "6890d93e-9b0f-4448-a2eb-270263edc7b7",
  "maskedCardNumber": "437512******5115",
  "expiryData": "2025-11-30T23:59:59Z",
  "expiryDate": "2025-11-30T23:59:59Z",
  "status": "CLOSED",
  "address": {
    "addressLine1": "Tallinn",
    "city": "Tallinn",
    "postalCode": "10113",
    "country": "EST",
    "dispatchMethod": "DHLExpress",
    "trackingNumber": "1234567890"
  },
  "isEnrolledFor3dSecure": false,
  "security": {
    "contactlessEnabled": true,
    "withdrawalEnabled": true,
    "internetPurchaseEnabled": true,
    "overallLimitsEnabled": true
  },
  "limits": {
    "dailyPurchase": 10000,
    "dailyWithdrawal": 350,
    "dailyInternetPurchase": 10000,
    "dailyContactlessPurchase": 10000,
    "weeklyPurchase": 15000,
    "weeklyWithdrawal": 3000,
    "weeklyInternetPurchase": 15000,
    "weeklyContactlessPurchase": 15000,
    "monthlyPurchase": 15000,
    "monthlyWithdrawal": 3000,
    "monthlyInternetPurchase": 15000,
    "monthlyContactlessPurchase": 15000,
    "transactionPurchase": 10000,
    "transactionWithdrawal": 350,
    "transactionInternetPurchase": 10000,
    "transactionContactlessPurchase": 200,
    "dailyOverallPurchase": 10000,
    "weeklyOverallPurchase": 10000,
    "monthlyOverallPurchase": 10000,
    "dailyContactlessPurchaseAvailable": 10000,
    "dailyContactlessPurchaseUsed": 0,
    "dailyInternetPurchaseAvailable": 10000,
    "dailyInternetPurchaseUsed": 0,
    "dailyOverallPurchaseAvailable": 10000,
    "dailyOverallPurchaseUsed": 0,
    "dailyPurchaseAvailable": 10000,
    "dailyPurchaseUsed": 0,
    "dailyWithdrawalAvailable": 350,
    "dailyWithdrawalUsed": 0,
    "monthlyContactlessPurchaseAvailable": 15000,
    "monthlyContactlessPurchaseUsed": 0,
    "monthlyInternetPurchaseAvailable": 15000,
    "monthlyInternetPurchaseUsed": 0,
    "monthlyOverallPurchaseAvailable": 10000,
    "monthlyOverallPurchaseUsed": 0,
    "monthlyPurchaseAvailable": 15000,
    "monthlyPurchaseUsed": 0,
    "monthlyWithdrawalAvailable": 3000,
    "monthlyWithdrawalUsed": 0,
    "weeklyContactlessPurchaseAvailable": 15000,
    "weeklyContactlessPurchaseUsed": 0,
    "weeklyInternetPurchaseAvailable": 15000,
    "weeklyInternetPurchaseUsed": 0,
    "weeklyOverallPurchaseAvailable": 10000,
    "weeklyOverallPurchaseUsed": 0,
    "weeklyPurchaseAvailable": 15000,
    "weeklyPurchaseUsed": 0,
    "weeklyWithdrawalAvailable": 3000,
    "weeklyWithdrawalUsed": 0
  },
  "linkedAccountId": "22eb9caee08de8410eb0b41c5afd249e",
  "parentWalletId": "a82afcee-6b53-4869-a41a-df34e6b228db",
  "linkedAccountCurrency": "EUR",
  "createdAt": "2023-12-04T18:14:05Z"
}

```

## Card Dispatch Webhooks

Following are examples of webhooks sent when the card is dispatched

JSON

```
{
  "name": "Satoshi Nakamoto",
  "id": "8e1e8f4c-b492-4071-8536-a0c52bce7c7d",
  "type": "PHYSICAL",
  "userId": "6890d93e-9b0f-4448-a2eb-270263edc7b7",
  "maskedCardNumber": "437512******5115",
  "expiryData": "2027-01-31T23:59:59Z",
  "expiryDate": "2027-01-31T23:59:59Z",
  "status": "DISPATCHED",
  "address": {
    "addressLine1": "Tallinn",
    "city": "Tallinn",
    "postalCode": "10113",
    "country": "EST",
    "dispatchMethod": "DHLExpress",
    "trackingNumber": "1234567890"
  },
  "isEnrolledFor3dSecure": false,
  "security": {
    "contactlessEnabled": true,
    "withdrawalEnabled": true,
    "internetPurchaseEnabled": true,
    "overallLimitsEnabled": true
  },
  "limits": {
    "dailyPurchase": 10000,
    "dailyWithdrawal": 350,
    "dailyInternetPurchase": 10000,
    "dailyContactlessPurchase": 10000,
    "weeklyPurchase": 15000,
    "weeklyWithdrawal": 3000,
    "weeklyInternetPurchase": 15000,
    "weeklyContactlessPurchase": 15000,
    "monthlyPurchase": 15000,
    "monthlyWithdrawal": 3000,
    "monthlyInternetPurchase": 15000,
    "monthlyContactlessPurchase": 15000,
    "transactionPurchase": 10000,
    "transactionWithdrawal": 350,
    "transactionInternetPurchase": 10000,
    "transactionContactlessPurchase": 50,
    "dailyOverallPurchase": 10000,
    "weeklyOverallPurchase": 10000,
    "monthlyOverallPurchase": 10000,
    "dailyContactlessPurchaseAvailable": 10000,
    "dailyContactlessPurchaseUsed": 0,
    "dailyInternetPurchaseAvailable": 10000,
    "dailyInternetPurchaseUsed": 0,
    "dailyOverallPurchaseAvailable": 10000,
    "dailyOverallPurchaseUsed": 0,
    "dailyPurchaseAvailable": 10000,
    "dailyPurchaseUsed": 0,
    "dailyWithdrawalAvailable": 350,
    "dailyWithdrawalUsed": 0,
    "monthlyContactlessPurchaseAvailable": 15000,
    "monthlyContactlessPurchaseUsed": 0,
    "monthlyInternetPurchaseAvailable": 15000,
    "monthlyInternetPurchaseUsed": 0,
    "monthlyOverallPurchaseAvailable": 10000,
    "monthlyOverallPurchaseUsed": 0,
    "monthlyPurchaseAvailable": 15000,
    "monthlyPurchaseUsed": 0,
    "monthlyWithdrawalAvailable": 3000,
    "monthlyWithdrawalUsed": 0,
    "weeklyContactlessPurchaseAvailable": 15000,
    "weeklyContactlessPurchaseUsed": 0,
    "weeklyInternetPurchaseAvailable": 15000,
    "weeklyInternetPurchaseUsed": 0,
    "weeklyOverallPurchaseAvailable": 10000,
    "weeklyOverallPurchaseUsed": 0,
    "weeklyPurchaseAvailable": 15000,
    "weeklyPurchaseUsed": 0,
    "weeklyWithdrawalAvailable": 3000,
    "weeklyWithdrawalUsed": 0
  },
  "linkedAccountId": "22eb9caee08de8410eb0b41c5afd249e",
  "parentWalletId": "a82afcee-6b53-4869-a41a-df34e6b228db",
  "linkedAccountCurrency": "EUR",
  "createdAt": "2024-01-02T16:08:35Z"
}

```

## Apple Pay Incentive Webhooks

An incomplete provisioning Apple Pay webhook is sent when a cardholder has commenced provisioning onto Apple Pay platform but has not completed provisioning within 7 days, for example -

JSON

```
{
  cardId: '8e1e8f4c-b492-4071-8536-a0c52bce7c7d',
  type: 'INCOMPLETE_PROVISIONING'
}
```

Similarly an Apple Pay incentive webhook is sent when a cardholder has completed provisioning onto Apple Pay but not made a successful payment with Apple Pay within 14 days, for example

JSON

```
{
  cardId: '8e1e8f4c-b492-4071-8536-a0c52bce7c7d',
  type: 'SUCCESSFUL_TRANSACTION'
}
```
