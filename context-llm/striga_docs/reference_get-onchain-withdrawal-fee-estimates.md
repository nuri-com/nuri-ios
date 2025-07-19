---
title: Get Withdrawal Fee Estimate
source_url: https://docs.striga.com/reference/get-onchain-withdrawal-fee-estimates
scraped_at: 2025-07-18 17:54:39
---

# Get Withdrawal Fee Estimate

JUMP TO

## A Gentle Introduction to Striga

- [Building on Striga - Money movement APIs](/reference/getting-started-with-your-api)
  - [Example: Crypto On-Ramps & Off-Ramps](/reference/crypto-on-ramps-off-ramps)
- [Getting Started with Striga](/reference/request-authentication)
- [Authenticating with the API (API Authentication)](/reference/authenticating-with-the-api)
  - [JS HMAC Sample Snippet](/reference/js-hmac-sample-snippet)
  - [PHP HMAC Sample Snippet](/reference/js-hmac-sample-snippet-copy)
  - [C# HMAC Sample Snippet](/reference/c-hmac-sample-snippet-1)
  - [Java HMAC Sample Snippet](/reference/java-hmac-sample-snippet-copy)
- [Testing with Postman](/reference/testing-with-postman)
- [Code Previews](/reference/code-previews)
- [KYC/KYB SDK](/reference/kyc-sdk)

## Webhook Notifications

- [Configuring Webhooks](/reference/configuring-webhooks)
- [Webhook Endpoints](/reference/webhook-endpoints)
  - [KYC Status Webhooks](/reference/kyc-status-webhooks)
  - [KYB Status Webhooks](/reference/kyb-status-webhooks)
  - [Card Transaction Webhooks](/reference/card-transaction-webhooks)
  - [Intra/Inter Platform Transaction Webhooks](/reference/intrainter-platform-transaction-webhooks)
  - [Crypto Deposit/Withdrawal Webhooks](/reference/crypto-depositwithdrawal-webhooks)
  - [Bank Transfer Webhooks](/reference/bank-transfer-webhooks)
  - [Lightning Network Transaction Webhooks](/reference/lightning-network-transaction-webhooks)
  - [Contract Call Webhooks](/reference/contract-call-webhooks)
  - [Currency Swap Webhooks](/reference/currency-swap-webhooks)
  - [Miscellaneous Webhooks](/reference/miscellaneous-webhooks)
  - [Card Status Webhooks](/reference/card-status-webhooks)

## End Users - Consumers & Businesses

- [Tiered KYC](/reference/kyc-tiers)
- [Consumer Onboarding Flow](/reference/onboarding-flow)
  - [Create Userpost](/reference/create-user)
  - [Update Userpatch](/reference/update-user)
  - [Verification Workflow](/reference/verification-workflow)
  - [Get User By IDget](/reference/get-user-details)
  - [Get User By Emailpost](/reference/get-user-by-email)
  - [Start KYCpost](/reference/start-kyc)
  - [Get KYC Statusget](/reference/get-kyc-status)
  - [Verify User Email Addresspost](/reference/verify-email-address)
    - [Resend Emailpost](/reference/resend-email)
  - [Verify User Mobilepost](/reference/verify-mobile-number)
    - [Resend SMSpost](/reference/resend-sms)
  - [Fetch User PII Datapost](/reference/fetch-user-pii-data)
- [Business Onboarding Flow](/reference/business)
  - [Create Businesspost](/reference/post_create-1)
  - [Update Businesspatch](/reference/patch_update)
  - [Get Business by IDget](/reference/get_businessid)
  - [Get Business by Emailpost](/reference/post_get-by-email)
  - [Verify Business Email Addresspost](/reference/post_verify-email)
  - [Resend Emailpost](/reference/post_resend-email)
  - [Verify Business Mobilepost](/reference/post_verify-mobile)
  - [Resend SMSpost](/reference/post_resend-sms)
  - [Start KYBpost](/reference/post_kyb-start)
  - [Get KYB Statusget](/reference/get_kyb-businessid)

## Enrichments

- [Creating Deposit Credentials](/reference/creating-deposit-credentials)
  - [Enrich Accountpost](/reference/enrich-account)

## Wallets & Accounts

- [Storing Value](/reference/storing-value)
- [Moving Money Around](/reference/moving-money-around-1)
  - [Initiate Intraledger Transactionpost](/reference/initiate-intraledger-transaction)
  - [Initiate Interledger Transactionpost](/reference/initiate-interledger-transaction)
  - [Initiate SEPA Paymentpost](/reference/initiate-sepa-payment)
  - [Whitelist Destination Addresspost](/reference/whitelist-destination-address)
  - [Get Whitelisted User Destination Addressespost](/reference/get-whitelisted-user-destination-addresses)
  - [Get Withdrawal Fee Estimatepost](/reference/get-onchain-withdrawal-fee-estimates)
  - [Initiate Onchain Withdrawalpost](/reference/initiate-onchain-withdrawal)
  - [Deposit via Lightningpost](/reference/initiate-topup-via-lightning)
  - [Initiate Bitcoin Lightning Withdrawalpost](/reference/initiate-bitcoin-via-lightning)
  - [Confirm transaction with OTPpost](/reference/confirm-transaction-with-otp)
    - [Validate IP Regionpost](/reference/validate-ip-region)
  - [Resend OTP for transactionpost](/reference/resend-otp-for-transaction)
  - [Get Transactions By Idpost](/reference/get-transactions-by-id-1)
- [Consumer Wallets & Transactions](/reference/consumers)
  - [Get Account Statementpost](/reference/get-account-statement)
  - [Get Account By Idpost](/reference/get-account-by-id)
  - [Get All Wallets By Userpost](/reference/get-all-wallets-for-a-user)
  - [Get Wallet By Idpost](/reference/get-wallet)
  - [Create Walletpost](/reference/create-wallet)
- [Business Wallets & Transactions](/reference/wallets)
  - [Create Business Walletpost](/reference/post_business-create)
  - [Get Wallet By Idpost](/reference/post_business-get)
  - [Get All Walletspost](/reference/post_business-get-all)
  - [Get Account By Idpost](/reference/post_business-get-account)
  - [Get Account Statementpost](/reference/post_business-get-account-statement)
  - [Get Account Statementpost](/reference/post_business-account-get-transactions-by-id)
  - [Enrich Accountpost](/reference/post_business-account-enrich)
  - [Whitelist Destination Addresspost](/reference/post_business-whitelist-address)
  - [Get Whitelisted Business Destination Addressespost](/reference/post_business-get-whitelisted-addresses)
  - [Swap Currenciespost](/reference/post_business-swap)
  - [Initiate Inter ledger Transactionpost](/reference/post_business-send-inter-initiate)
  - [Initiate Intra ledger Transactionpost](/reference/post_business-send-intra-initiate)
  - [Get Withdrawal Fee Estimatepost](/reference/post_business-send-initiate-onchain-fee-estimate)
  - [Initiate Onchain Withdrawalpost](/reference/post_business-send-initiate-onchain)
  - [Deposit via Lightningpost](/reference/post_business-account-lightning-topup)
  - [Initiate Bitcoin Lightning Withdrawalpost](/reference/post_business-send-initiate-lightning)
  - [Confirm transaction with OTPpost](/reference/post_business-transaction-confirm)
  - [Resend OTP for transactionpost](/reference/post_business-transaction-resend-otp)
  - [Initiate SEPA Paymentpost](/reference/post_business-send-initiate-bank)

## HOSTED CARDS

- [Plug and Play Visa Cards](/reference/plug-and-play-visa-cards)
  - [Start Hosted Card Sessionpost](/reference/create-hosted-card-session)
  - [Set Allowed Wallet Currenciespatch](/reference/set-allowed-wallet-currencies)
  - [Get Allowed Wallet Currenciesget](/reference/get-allowed-wallet-currencies)
- [User MFA (Multi Factor Authentication)](/reference/user-mfa-multi-factor-authentication)
  - [Start MFA Setuppost](/reference/start-mfa-setup)
  - [Resume MFA Setuppost](/reference/start-mfa-setup-copy)
- [Customizing the Hosted Cards User Interface](/reference/customizing-hosted-card-ui)
  - [Set Custom CSSpost](/reference/set-custom-css)
  - [Get Custom CSSget](/reference/get-custom-css)

## Cards

- [Creating and Managing Cards](/reference/creating-and-managing-cards)
  - [Linking Accounts](/reference/linking-accounts)
  - [Create Cardpost](/reference/create-card)
  - [Get Cardget](/reference/get-card-api)
  - [Link Accountpatch](/reference/link-account)
  - [Destroy a Virtual Cardpost](/reference/burner-cards-close-a-virtual-card)
  - [Update Card Limitspatch](/reference/update-card-limits)
  - [Update Card Settingspatch](/reference/update-card-settings)
  - [Update 3D Secure Settingspatch](/reference/update-3ds-settings)
  - [Set Card PINpatch](/reference/set-pin)
  - [Report Card Missingpost](/reference/report-card-lost)
  - [Activate Physical Cardpost](/reference/activate-card)
  - [Activate Anonymous Cardpost](/reference/activate-anonymous-card)
  - [Replace Cardpost](/reference/replace-card)
  - [Unblock Cardpost](/reference/unblock-card)
  - [Block Cardpost](/reference/block-card)
  - [Get Card Statementpost](/reference/get-card-statements)
  - [Get Cards By Userpost](/reference/get-cards-by-user)
- [Card PAN UI Components](/reference/overview)
  - [Customization](/reference/customisation)
  - [Methods](/reference/methods)
    - [Create](/reference/create)
    - [Request Consent](/reference/request-consent)
    - [Render](/reference/render)
  - [Revoke Consent (UI)post](/reference/revoke-consent-ui)
  - [Resend Consent Code (UI)post](/reference/resend-consent-code-ui)
  - [Confirm Consent (UI)post](/reference/confirm-consent-ui)
- [Tokens](/reference/tokens)
  - [Get Tokenpost](/reference/get-token)
  - [Activate Tokenpost](/reference/activate-token)
  - [Get All Card Tokenspost](/reference/get-all-card-tokens)
  - [Suspend Tokenpost](/reference/suspend-token)
  - [Resume Tokenpost](/reference/resume-token)
  - [Deactivate Tokenpost](/reference/deactivate-token)
  - [Apple Pay Push Provisioningpost](/reference/apple-pay-push)
  - [Google Pay Push Provisioningpost](/reference/google-pay-push)

## Standing Orders

- [Automated Swaps & Withdrawals](/reference/standing-orders)
  - [Create Standing Orderpost](/reference/post_create)
  - [Resend Standing Order OTPpost](/reference/post_resend-otp)
  - [Confirm or Cancel a standing order with an OTPpost](/reference/post_confirm)
  - [Cancel Standing Orderpost](/reference/post_cancel)
  - [Get all standing orderspost](/reference/post_get-all)
  - [Get one standing order by its IDpost](/reference/post_get-by-id)
  - [Resume/Execute Standing Orderpost](/reference/post_resume)

## Exchange

- [Currency Swaps](/reference/swap-currencies)
  - [Swap Currenciespost](/reference/swap-currency)
  - [Exchange Ratespost](/reference/exchange-rates)

## Managing your corporate

- [Your Corporate Account at Striga](/reference/your-corporate-account-at-striga)
  - [Corporate Swapspost](/reference/swap-currencies-corporate)
  - [Get Corporate Account Statementpost](/reference/get-corporate-account-statement)
  - [Get All Corporate Accountspost](/reference/get-all-corporate-accounts)
  - [Get Corporate Account By Idpost](/reference/get-corporate-account-by-id)
  - [Whitelist Corporate Destination Addresspost](/reference/whitelist-corporate-destination-address)
  - [Get Whitelisted Corporate Destination Addressespost](/reference/get-whitelisted-corporate-destination-addresses)

## Error Codes

- [Error Codes](/reference/error-codes)

Powered by

Ask AI

# Get Withdrawal Fee Estimate

post https://www.sandbox.striga.com/api/v1/wallets/send/initiate/onchain/fee-estimate

Get a fee estimate for an onchain withdrawal without triggering a withdrawal

Language

Shell

Credentials

Header +1

RESPONSE

Click `Try It!` to start a request and see the response here!
