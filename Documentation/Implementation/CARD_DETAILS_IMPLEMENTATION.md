# Card Details Display - Implementation Guide

## Overview
This implementation follows the hybrid approach for displaying card details securely using Striga's JavaScript SDK combined with native iOS UI components.

## Architecture

### Key Components

1. **CardDetailsWebView** (`CardDetailsWebView.swift`)
   - Main orchestrator view
   - Contains hidden webview for consent request
   - Shows visible webview for card rendering
   - Manages the entire flow

2. **CardConsentWebView** (`CardConsentWebView.swift`)
   - Hidden WKWebView that loads Striga JS SDK
   - Executes `requestConsent()` to trigger OTP
   - Returns challengeId to Swift
   - Can also render card details with auth token

3. **CardOTPConsentView** (`CardOTPConsentView.swift`)
   - Native SwiftUI sheet for OTP entry
   - Sends OTP to proxy server endpoint
   - Returns auth token on success

4. **CardRenderWebView** (in `CardDetailsWebView.swift`)
   - Visible webview for displaying card details
   - Uses Striga's secure iframes
   - Renders card number and CVV

## Flow Sequence

```
1. User taps "Show" button in CardViewActive
   ↓
2. CardDetailsWebView opens (fullscreen cover)
   ↓
3. Hidden CardConsentWebView loads and calls JS requestConsent()
   ↓
4. Striga sends OTP to user's phone/email
   ↓
5. JS returns challengeId to Swift
   ↓
6. CardOTPConsentView sheet appears for OTP entry
   ↓
7. User enters 6-digit code (sandbox: 123456)
   ↓
8. OTP sent to proxy: POST https://passkey.nuri.com/striga/confirm-consent
   {
     "userId": "...",
     "challengeId": "...",
     "verificationCode": "123456"
   }
   ↓
9. Proxy server validates with Striga API (with proper signing)
   ↓
10. Proxy returns: { "cardAuthToken": "..." }
    ↓
11. CardRenderWebView displays with auth token
    ↓
12. JS renders secure iframes with full card details
```

## Proxy Server Endpoints

### `/striga/confirm-consent`
- **Method:** POST
- **Purpose:** Confirm OTP and get auth token
- **Request Body:**
  ```json
  {
    "userId": "string",
    "challengeId": "string",
    "verificationCode": "string"
  }
  ```
- **Response:**
  ```json
  {
    "cardAuthToken": "string"
  }
  ```

### `/striga/resend-consent-code`
- **Method:** POST
- **Purpose:** Resend OTP code
- **Request Body:**
  ```json
  {
    "userId": "string",
    "challengeId": "string"
  }
  ```

## Security Features

1. **No Direct Card Data Handling**
   - Card details are rendered in Striga's secure iframes
   - iOS app never sees raw card numbers or CVV

2. **Proxy Server Protection**
   - API secrets are kept on server only
   - Request signing happens server-side
   - iOS app only handles user-facing data

3. **Time-Limited Auth Tokens**
   - Auth tokens expire after short period
   - New consent required for each viewing session

## Testing

### Sandbox Environment
- OTP code is always: `123456`
- Both SMS and email channels work
- Test with real phone numbers (OTP won't actually send)

### Production Considerations
1. Update proxy server URL from development to production
2. Ensure proxy server has production Striga credentials
3. Test with real OTP delivery
4. Add proper error handling for network failures
5. Consider adding biometric authentication before showing cards

## Troubleshooting

### Common Issues

1. **"Multi-factor authentication not enabled"**
   - User needs to verify BOTH email and phone
   - Check user verification status in Striga

2. **Challenge ID expired**
   - Challenge IDs expire after 5 minutes
   - Implement automatic retry with new consent request

3. **Card not rendering**
   - Check auth token is valid
   - Ensure card ID matches user's card
   - Verify Striga JS SDK loaded properly

## Future Enhancements

1. **Biometric Authentication**
   - Add Face ID/Touch ID before card display
   - Store auth token in Keychain briefly

2. **Copy Card Details**
   - Add native buttons to copy card number/CVV
   - Use JavaScript bridge to extract from iframes

3. **Card Image Display**
   - Show visual card representation
   - Match user's actual card design

4. **Transaction History**
   - Show recent transactions below card
   - Link to full transaction history