---
title: Plug and Play Visa Cards
source_url: https://docs.striga.com/reference/plug-and-play-visa-cards
scraped_at: 2025-07-18 17:55:40
---

# Plug and Play Visa Cards

The "hosted cards" feature allows you to get up and running in as short a timeframe as possible, utilizing Striga's pre-approved Visa card program, featuring our generic unbranded card.

![](https://files.readme.io/c9c533cb01d201672fccb494865cef33316563e3a37fc1bc8c2e4543fcbeceef-image.png)

The feature is designed to be a drag and drop integration into your existing Striga integration, in a manner where the user is primarily authenticating with your application and authenticating with Striga through a TOTP that is setup through your user interface.

Each card must be linked to a funding source however and your application can determine which funding source currencies are allowed for this feature by using the "Set Allowed Wallet Currencies" API. Only the **DEFAULT** "Wallet" object (Remember, a wallet is a collection of accounts, one in each currency, on Striga) is used as a possible funding source selector within the hosted cards application.

To place hosted cards inside your application, you need to do the following -

1. Setup user MFA within your application
2. (Optional) - Set a list of allowed currencies that the card can be linked to (Default: All currencies that Striga supports. Currently BTC, ETH, USDC, BNB and POL).
3. Retrieve a `sessionId` by starting a hosted card session

A hosted card session is valid for 15 minutes by default after which a new session ID should be created to initialize the widget, using a `sessionId` ,`userId`, `applicationId`and `uiSecret`

For example, the URL inside your iframe would be as follows: `https://cards-sandbox.striga.com?sessionId={sessionId}&userId={ userId }&applicationId={applicationId}&uiSecret={uiSecret}`

**Important**: To ensure copy-to-clipboard functionality works inside the embedded iframe, you must include allow="clipboard-write" in your <iframe> tag. Without this, users won’t be able to copy card number or cvv, as browsers will block clipboard access.

Example:

```
<iframe
  width="100%"
  height="100%"
  allow="clipboard-write"
/>
```

| Environment | URL |
| --- | --- |
| Sandbox | <https://cards-sandbox.striga.com/> |
| Production | Upon Request |

**NOTE**: When the session expires, the iframe will trigger an event to notify the parent window. To handle this event, add an event listener for the `session-expired event` as follows:

```
window.addEventListener('message', function(event) {
  if (event.data && event.data.event === 'session-expired') {
    alert(event.data.message); 
  }
});
```

Sample Event:

```
{
  event: 'session-expired',
  message: 'Session expired. Please generate a new sessionId.'
}
```

**NOTE**: When you press the back button on the cards screen, the iframe will trigger an event to notify the parent window. To handle this event, add an event listener for the `close` event as follows:

```
window.addEventListener('message', function(event) {
  if (event.data && event.data.event === 'close') {
    alert(event.data.message); 
  }
});
```

Sample Event:

```
{
  event: 'close'
}
```

Striga is responsible for providing these card services and hence, the lifecycle of card display, card management etc. is handled inside the widget as per Visa's requirements.

Hosted cards can be added to Google Pay, Samsung Pay, Fitbit Pay and Garmin Pay by default. If you would like to enable Apple Pay please discuss this with your account manager during onboarding (or contact us on [[email protected]](/cdn-cgi/l/email-protection#026a676e6e6d427176706b65632c616d6f))

> 📘
>
> ### Hosted Cards on Production
>
> Please note that on the production environment, the admin panel will contain basic card information but you will not be able to make admin actions on user cards as this is managed by Striga. Moreover, the card APIs will not be accessible using the standard API key methods until your own Visa card program is approved.
>
> On the sandbox, by default all applications have access to card APIs and the hosted card widget.
