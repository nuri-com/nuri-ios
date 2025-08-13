# Striga Card Display Architecture

## Overview
This document explains how we display card details in the Nuri iOS app using Striga's secure infrastructure.

## Key Concepts

### 1. PCI Compliance Requirements
- **Full PAN (Primary Account Number)**: Can ONLY be displayed in Striga's secure iframes
- **CVV**: Can ONLY be displayed in Striga's secure iframes  
- **Card Holder Name**: Can be displayed natively
- **Expiry Date**: Can be displayed natively

### 2. Why We Use This Approach

#### The Challenge
- Striga offers two card management approaches:
  1. **Hosted Card UI**: Full UI provided by Striga (requires MFA - email AND phone)
  2. **Custom Integration**: Build your own UI using their SDK

- We chose **Custom Integration** because:
  - We want single-factor authentication (OTP only, not full MFA)
  - Better UX control and integration with our app design
  - Streamlined flow without multiple verification steps

#### Our Solution
We use a hybrid approach:
1. **Native SwiftUI** for non-sensitive data (name, expiry)
2. **Striga Secure iframes** for sensitive data (PAN, CVV)

## Technical Flow

### Step 1: Request Consent
```javascript
// In WebView via JavaScript SDK
StrigaUXPlugin.requestConsent({ userId, channel: 'sms' })
// Returns: challengeId
```

### Step 2: OTP Verification
```swift
// Send to proxy server
POST /striga/confirm-consent
{
  userId, challengeId, verificationCode
}
// Returns: cardAuthToken
```

### Step 3: Display Card Details

#### 3a. Fetch Non-Sensitive Data (Native Display)
```swift
// Via API or proxy
GET /api/v1/card/{cardId}
// Returns: name, expiryMonth, expiryYear, maskedCardNumber
```

#### 3b. Display Sensitive Data (Secure iframes)
```javascript
// MUST use Striga SDK with authToken
StrigaUXPlugin.render('cardNumber', {
  cardId: cardId,
  authToken: authToken,  // CRITICAL - enables unmasked display
  hideData: false
})

StrigaUXPlugin.render('cvv', {
  cardId: cardId,
  authToken: authToken,  // CRITICAL - enables unmasked display
  hideData: false
})
```

## Important Security Notes

### What the Auth Token Does
- The `cardAuthToken` from consent verification is a **temporary token** (24 hours)
- It authorizes display of FULL card details
- Without it, you only get masked data (4743 67** **** 7720)
- With it, you get full data (4743 6712 3456 7720)

### PCI Compliance
- We CANNOT extract card numbers from iframes (blocked by same-origin policy)
- We CANNOT store full PAN or CVV in our app
- We MUST use Striga's secure iframes for display
- The iframes are served from `vault.striga.eu` (PCI-compliant infrastructure)

## File Structure

```
CardDetailsFlowView.swift
├── Native UI Components
│   ├── Card Holder Name (from API)
│   └── Expiry Date (from API)
│
└── WebView Component
    └── striga_card_display.html
        ├── cardNumber iframe (Striga SDK)
        └── cvv iframe (Striga SDK)
```

## Common Issues & Solutions

### Issue: Only seeing masked card numbers
**Cause**: Auth token not being passed correctly to render()
**Solution**: Ensure authToken is passed in the render() call

### Issue: HMAC signature errors
**Cause**: Trying to pass authToken as query parameter to REST API
**Solution**: Use proxy server or don't pass authToken to REST endpoints

### Issue: iframes not displaying
**Cause**: WebView hidden or too small
**Solution**: WebView must be visible with adequate height (min 180px)

## Testing

### Sandbox Environment
- OTP Code: Always `123456`
- Test cards are pre-created with specific numbers
- Auth tokens valid for 24 hours

### Verification Steps
1. Check console logs for "Card number rendered" and "CVV rendered"
2. Verify iframes are created in WebView DOM
3. Confirm auth token is being passed to render() calls
4. Ensure WebView is visible and properly sized

## Summary

This architecture ensures:
- ✅ PCI compliance (sensitive data in secure iframes)
- ✅ Good UX (native UI for non-sensitive data)
- ✅ Security (temporary auth tokens, no data storage)
- ✅ Simplified auth (OTP only, not full MFA)