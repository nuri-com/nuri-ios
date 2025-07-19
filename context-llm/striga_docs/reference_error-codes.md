---
title: Error Codes
source_url: https://docs.striga.com/reference/error-codes
scraped_at: 2025-07-18 17:50:04
---

# Error Codes

> 🚧
>
> ### Under Development
>
> Please note, these error codes are under development as we move documentation to an OpenAPI spec. with well typed requests/responses and error messages. Until then, the below is meant to serve as a reference only.

| Error Code | Description |
| --- | --- |
| 00000 | Default Error Code - Invalid fields passed in request body |
| 00001 | Internal Server Error |
| 00002 | Validator Errors - Invalid fields passed in request body |
| 00003 | Exceeded Email Verification Attempt Count |
| 00004 | Card product configuration error |
| 00005 | Exceeded Forgot Password Attempt Count |
| 00006 | Forgot Password Session Error |
| 00010 | Error Refreshing Refresh Token - Expired JWT/Refresh Token or FA Error |
| 00011 | Application Does Not Exist |
| 00012 | Feature not implemented yet |
| 00013 | Internal Service Error |
| 30000 | Invalid API Key |
| 30002 | Exceeded Email Verification Attempt Count |
| 30003 | Exceeded Mobile Verification Attempt Count |
| 30004 | Invalid Mobile Verification Code |
| 30005 | User does not exist |
| 30006 | Invalid patch user |
| 30007 | User not verified |
| 30008 | User is already verified |
| 30009 | User verification is in progress |
| 30010 | KYC rejected, user cannot retry |
| 30011 | KYC attempt limit exceeded |
| 30012 | Invalid Authentication Header |
| 30013 | Invalid request - Card ID & User ID mismatch |
| 30014 | Third-party API failure |
| 30015 | Invalid card limits |
| 30016 | Card is not of type physical |
| 30017 | Card is already blocked |
| 30018 | Card should be blocked to be unblocked |
| 30019 | 3D Secure should be enabled for the card before activation |
| 30020 | 3D Secure is already disabled |
| 30021 | 3D Secure is not enabled |
| 30022 | Invalid card ID |
| 30023 | Card can be activated only if it is ordered |
| 30024 | Card can be blocked only when the card is activated (applies to only physical cards) |
| 30025 | Card cannot be unblocked if it was blocked as Lost or Stolen |
| 30026 | Card 3D Secure cannot be enabled when not in 'ACTIVE' state for physical cards |
| 30027 | Card cannot be activated if it is not in "Dispatched" status |
| 30028 | Card activation error |
| 30029 | Insufficient Permissions to Access Resource |
| 30030 | Email & Mobile not verified to start KYC |
| 30031 | Bad transfer request |
| 30032 | Cannot start KYC |
| 30033 | Non-ACTIVE card being linked |
| 30034 | This account cannot be linked to this card |
| 30036 | Please request an OTP before verifying |
| 30037 | Please provide at least one transaction fee to update |
| 30038 | Email cannot be the same as the existing email |
| 30039 | Email already exists |
| 30040 | Mobile cannot be the same as the existing mobile number |
| 30041 | Mobile number already exists |
| 30042 | This route is restricted and cannot be accessed |
| 30043 | User is suspended |
| 30044 | Email/Mobile already verified |
| 30045 | Below Minimum Trade Value |
| 30046 | Restricted Jurisdiction |
| 30059 | Cannot replace card |
| 30060 | Error fetching token provisioning data |
| 30061 | Card does not exist |
| 30099 | Disallowed Transaction |
| 30100 | Card not active |
| 30101 | Card does not have a PIN |
| 31001 | Invalid IBAN/BIC |
| 31002 | Account not enriched |
| 31003 | Self SEPA transfer attempted |
| 31004 | Insufficient balance |
| 31005 | SEPA destination is a non-enriched or inactive account |
| 31006 | LN withdrawal in progress |
| 31007 | Self LN transfer attempted |
| 31008 | Exceeded Mobile Resend Count |
| 31009 | Mobile number already verified |
| 31010 | Exceeded Email Resend Count |
| 31011 | Wallet ID not found |
| 31012 | Error occurred while creating the card |
| 31024 | Core service error |
| 31025 | Error while initiating LN transaction |
| 31026 | Error while initiating SEPA transaction |
| 31027 | Error encountered during instant swap process |
| 31028 | Please try again later. Too many attempts? |
| 31029 | Error while sending multi-currency transaction |
| 31030 | Error while initiating inter/intra transaction |
| 31031 | Error while processing external service provider |
| 31032 | Error while initiating on-chain transaction |
| 31033 | Error while fetching email/mobile expiry details |
| 31038 | Invalid fee estimate - Please verify configured fee parameters |
| 31047 | Error accessing the requested resource |
| 31048 | Account operation expired |
| 31055 | Rate limit exceeded |
| 31062 | Funds cannot be sent in this direction |
| 31064 | Invalid OTP |
| 31065 | Too many 2FA attempts |
| 31067 | Invalid transaction type specified |
| 31069 | Mobile number not set for the account |
| 31073 | Invalid wallet ID provided |
| 31075 | Invalid user ID provided |
| 31078 | Invalid withdrawal fee specified |
| 31079 | Account has already been enriched |
| 31081 | Error occurred during enrichment process |
| 31082 | Invalid currency specified |
| 31083 | User not found in the system |
| 31088 | Trade value is below the minimum allowed |
| 31090 | Insufficient balance for the transaction |
| 31092 | Error occurred while creating user account |
| 31093 | Error occurred while patching user data |
| 31094 | Error encountered while sending verification code |
| 32012 | Card creation limit reached |
| 32013 | accountIdToLink is required when a fee is configured |
| 32014 | Invalid account ID for this operation |
| 32015/31009 | Mobile number already exists |
| 32016 | Invalid mobile number |
| 32017 | User is terminated |
| 41001 | Invalid currency/network pair |
| 41002 | Address already whitelisted |
| 41003 | Address cannot be whitelisted |
| 41004 | Address not whitelisted |
| 41005 | Invalid destination address on send |
| 41006 | Invalid address |
| 41007 | Account lacks permissions for this feature |
| 41008 | Withdrawal fees exceed the amount |
| 41009 | Liquidity provider error |
| 60001 | User limit exceeded |
