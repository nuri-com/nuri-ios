# Testing Guide - Card Details Display with Proxy Server

## Prerequisites
✅ Proxy server deployed at `https://passkey.nuri.com/striga/*`
✅ iOS app updated with new card display flow
✅ User has verified email AND phone number in Striga
✅ User has an active card

## Test Flow

### 1. Start Card Display Flow
1. Open the app and navigate to Card view
2. Tap the "Show" button under the card
3. **Expected:** Full screen cover appears with "Requesting card access..." message

### 2. Consent Request (Hidden WebView)
- **Behind the scenes:** Hidden webview loads Striga JS SDK
- **JS Call:** `StrigaUXPlugin.requestConsent({ userId: 'xxx', channel: 'sms' })`
- **Expected:** User receives SMS with 6-digit code (sandbox: always `123456`)

### 3. OTP Entry (Native Sheet)
1. OTP sheet automatically appears after consent request
2. Enter the 6-digit code: `123456` (sandbox)
3. Tap "Confirm"
4. **Alternative:** Tap "Resend Code" to request new OTP

### 4. Proxy Server Communication
- **Request to:** `POST https://passkey.nuri.com/striga/confirm-consent`
- **Payload:**
  ```json
  {
    "userId": "xxx",
    "challengeId": "xxx", 
    "verificationCode": "123456"
  }
  ```
- **Expected Response:**
  ```json
  {
    "cardAuthToken": "xxx"
  }
  ```

### 5. Card Rendering (WebView with Secure iframes)
- **After receiving auth token:** Card display webview shows
- **JS Calls:**
  - `StrigaUXPlugin.renderCardNumberElement({ cardId, authToken }, 'cardNumber')`
  - `StrigaUXPlugin.renderCVVElement({ cardId, authToken }, 'cvv')`
- **Expected:** Full card number and CVV displayed in secure iframes

## Console Logs to Monitor

```
[CardView] 👁️ SHOW: Starting secure card display flow
[CardView]   1) Hidden WebView: JS requestConsent -> challengeId
[CardView]   2) Native Sheet: Collect OTP code
[CardView]   3) Proxy Server: confirm-consent -> authToken
[CardView]   4) WebView: Render card in secure iframes

[CardDetails] Got challengeId: xxx

[OTP] Sending to proxy: https://passkey.nuri.com/striga/confirm-consent
[OTP] Payload: userId=xxx, challengeId=xxx, code=123456
[OTP] Response status: 200
[OTP] ✅ Got auth token from proxy

[CardDetails] Got auth token
```

## Error Scenarios to Test

### 1. Wrong OTP Code
- Enter wrong code (not `123456`)
- **Expected:** Error message: "Invalid code. Please check and try again."

### 2. Expired Challenge
- Wait 5+ minutes before entering OTP
- **Expected:** Error message: "Code expired. Please request a new one."

### 3. Network Error
- Turn off network before confirming OTP
- **Expected:** Network error message

### 4. User Not Verified
- Test with user who hasn't verified email/phone
- **Expected:** Error about MFA not enabled

## Proxy Server Endpoints

### Confirm Consent
```bash
curl -X POST https://passkey.nuri.com/striga/confirm-consent \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-id",
    "challengeId": "test-challenge-id",
    "verificationCode": "123456"
  }'
```

### Resend Code
```bash
curl -X POST https://passkey.nuri.com/striga/resend-consent-code \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-id",
    "challengeId": "test-challenge-id"
  }'
```

## Troubleshooting

### Issue: "Multi-factor authentication not enabled"
**Solution:** User needs to verify both email AND phone number in Striga

### Issue: No OTP received
**Solution:** In sandbox, OTP doesn't actually send. Use `123456` always.

### Issue: Card not rendering
**Check:**
1. Auth token is valid
2. Card ID matches user's card
3. Striga JS SDK loaded properly
4. Network connectivity to Striga vault domain

### Issue: Proxy returns 404
**Check:**
1. URL is exactly: `https://passkey.nuri.com/striga/confirm-consent`
2. Method is POST
3. Content-Type header is `application/json`

## Production Checklist
- [ ] Update proxy server with production Striga credentials
- [ ] Test with real OTP delivery (not sandbox `123456`)
- [ ] Add rate limiting on proxy endpoints
- [ ] Add request logging for debugging
- [ ] Implement auth token caching (optional)
- [ ] Add biometric authentication before card display (optional)