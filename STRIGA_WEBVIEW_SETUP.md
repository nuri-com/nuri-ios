# Striga Card Consent WebView Integration

## Overview

The card consent flow for viewing sensitive card data (PAN, CVV) must be done through Striga's JavaScript UI library, not through REST API. This is required for PCI compliance.

## Configuration Required

You need to obtain two credentials from your Striga dashboard:

1. **UI Secret** - Used to authenticate the JavaScript UI library
2. **Application ID** - Identifies your application

## Setup Steps

1. **Get Credentials from Striga Dashboard**
   - Log into your Striga dashboard
   - Navigate to the API/Integration settings
   - Find your UI Secret and Application ID

2. **Update Configuration Files**
   
   Replace `YOUR_UI_SECRET` and `YOUR_APPLICATION_ID` in the following files:
   
   - `/Nuri/Nuri/Sources/Services/CardCreationService.swift`
   - `/Nuri/Nuri/Sources/Views/Card/CardVerificationView.swift`
   - `/Nuri/Nuri/Sources/Views/Create Card/Phone Number/PhoneNumberViewModel.swift`
   - `/Nuri/Nuri/Sources/Views/Create Card/Enter SMS Code/EnterSMSCodeViewModel.swift`
   - `/Nuri/Nuri/Sources/Views/Security/SecurityView.swift`

   Example:
   ```swift
   striga.configuration = StrigaConfiguration(
       url: "https://www.sandbox.striga.com/api/",
       key: "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=",
       secret: "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=",
       uiSecret: "your-actual-ui-secret-here",
       applicationId: "your-actual-application-id-here"
   )
   ```

## How It Works

1. **User clicks "Show" button** in CardViewActive
2. **CardVerificationView opens** and checks for UI credentials
3. **WebView loads** with Striga's JavaScript UI library
4. **JavaScript calls `requestConsent()`** which sends SMS/email to user
5. **User receives challenge ID** from JavaScript callback
6. **User enters verification code** in native iOS view
7. **App calls `confirmConsent` REST API** with challenge ID and code
8. **App receives auth token** to fetch card details
9. **Card details displayed** using the auth token

## Testing

For sandbox testing:
- Use real phone numbers and emails that can receive codes
- The verification codes are actual SMS/email codes sent by Striga
- Test code "123456" will NOT work with the real WebView flow

## Important Notes

- The WebView is required for the initial consent request
- The confirmation can be done via REST API
- The auth token expires, so card details need to be re-verified periodically
- This flow ensures PCI compliance by keeping sensitive data handling within Striga's secure environment

## Troubleshooting

If you see "Card verification requires Striga UI credentials":
1. Make sure you've updated all configuration files
2. Verify the credentials are correct from your Striga dashboard
3. Check that you're not using the placeholder values

If the WebView doesn't load:
1. Check internet connectivity
2. Verify the CDN URL is accessible: https://cdn.striga.com/ui/v1/striga-ui.js
3. Check console logs for JavaScript errors