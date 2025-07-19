---
title: Tokens
source_url: https://docs.striga.com/reference/tokens
scraped_at: 2025-07-18 17:50:02
---

# Tokens

Use the following APIs to manage the lifecycle of tokens when implementing manual or push provisioning.

To understand which token was provisioned to which wallet, all token API responses will contain a `requestorId` mapped as follows -

| Wallet | requestorId |
| --- | --- |
| Apple Pay | 40010030273 |
| Google Pay | 4001007500 |
| Samsung Pay | 40010043095 |
| Fitbit Pay | 40010077056 |
| Fidesmo Pay | 40010080419 |
| Garmin Pay | 40010069887 |

The `type` parameter of the token API responses can be understood as follows -

| type | Description |
| --- | --- |
| CARD\_ON\_FILE | This card is used for a subscription service |
| SECURE\_ELEMENT | The card is enrolled into a wallet, eg: Apple Pay |
| HCE | (Only for Android and EEA) - HCE based contactless transactions for payment apps in the EEA |
| QRC | Quick Response Code - Payments via QR codes |
| ECOMMERCE | The card is saved for an e-commerce purchase |

For Apple Pay for example, a `requestorId` of `40010030273` + a `type` of `SECURE_ELEMENT` and a `status` of `ACTIVE` would mean that the card is enrolled into Apple Pay.
