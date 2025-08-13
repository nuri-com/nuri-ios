# Striga Card Display Flow - iOS Implementation

## 🚨 CRITICAL UNDERSTANDING
**`request-consent` is NOT a REST API endpoint!** It's a JavaScript SDK method that ONLY exists in the browser/WebView context.

## Two Valid Approaches for iOS

### Approach 1: Hosted Card UI (Currently Implemented) ✅
This is what we're using - Striga's pre-built hosted card UI.

**Flow:**
1. **iOS Native:** Call REST API `/api/v1/hosted-card/start-session`
2. **iOS Native:** Get session ID from response
3. **iOS Native:** Open WKWebView with URL: `https://cards-sandbox.striga.com?sessionId=...`
4. **WebView:** Striga handles everything (consent, OTP, display)

**Pros:**
- Simple implementation
- Striga manages the entire UI/UX
- Automatic updates when Striga changes their flow

**Cons:**
- Less control over UI customization
- Must use Striga's design

### Approach 2: Custom WebView Implementation (Your Friend's Suggestion)
Build your own WebView content and use Striga's JavaScript SDK directly.

**Flow:**
1. **iOS Native:** Load custom HTML with Striga JS SDK into WKWebView
2. **WebView JS:** Call `StrigaUXPlugin.requestConsent({ userId })` → get `challengeId`
3. **iOS Native:** Send challengeId to YOUR backend
4. **Your Backend:** Call REST API `/api/v1/card/confirm-consent` with OTP
5. **Your Backend:** Return `cardAuthToken` to iOS
6. **WebView JS:** Call `StrigaUXPlugin.render()` with token to show card

**Pros:**
- More control over UI
- Can customize the flow
- Can handle OTP entry natively if desired

**Cons:**
- More complex implementation
- Must maintain your own WebView HTML/JS
- Need backend endpoint to proxy confirm-consent

## What We DO and DON'T Do

### ✅ We DO:
- Use Hosted Card UI (Approach 1) for simplicity
- Call REST API `/api/v1/hosted-card/start-session` to create session
- Open WebView with Striga's hosted card URL
- Let Striga handle consent flow inside their WebView

### ❌ We DON'T:
- Call `/api/v1/card/request-consent` as REST API (IT DOESN'T EXIST!)
- Try to handle consent purely in native iOS code
- Skip the WebView requirement

## Sandbox Behavior

### In Sandbox:
- **No real SMS/Email sent** - This is by design
- **OTP is always `123456`** - Fixed for testing
- **Prerequisites:** User must be ACTIVE/KYC'd with verified email & phone

### Error: "Multi-factor authentication not enabled"
This means the user hasn't verified their email AND phone. Both are required.

## The Confusion Explained

The documentation shows:
```javascript
// This is JAVASCRIPT code, not REST API!
const response = await StrigaUXPlugin.requestConsent({
    userId: USER_ID,
});
```

Many developers mistakenly think this translates to:
```bash
# THIS DOESN'T WORK - Not a REST endpoint!
POST /api/v1/card/request-consent
```

But it's ONLY available in JavaScript within a WebView context.

## HMAC Signing (For Backend Calls)

When calling Striga REST APIs like `confirm-consent`:
1. Timestamp in milliseconds
2. Sign path WITHOUT `/api/v1` prefix
3. Include MD5 hash of request body
4. Format: `Authorization: HMAC <timestamp>:<signature>`

## Summary

**For iOS apps:** Use the Hosted Card UI approach. It's simpler and Striga-recommended.

**If you need custom UI:** Implement Approach 2 with custom WebView and backend proxy.

**Never:** Try to call `request-consent` as a REST API - it will timeout because it doesn't exist!