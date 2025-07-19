---
title: Methods
source_url: https://docs.striga.com/reference/methods
scraped_at: 2025-07-18 17:55:57
---

# Methods

Striga's JavaScript UI library allows you to capture and display sensitive details using customizable UI views without information ever touching your servers. This ensures that you are entirely out of scope of PCI compliance

## Striga Client SDK

To use the Striga Client SDK, simply add the following code to the `<head>` of your project:

HTML

```

<!-- Striga JS client SDK -->
<script src="https://www.vault.striga.eu/web/sandbox/v1.1/client.min.js"></script>
```

## UX methods

1. **[Create Method](/reference/create)**: The create method is used to initiate the UI component with the secret key and application ID.
2. **[Request Consent Method](/reference/request-consent)**: The `requestConsent` method is used to send an OTP to the user's mobile number and email ID for verification.
3. **[Render Method](/reference/render)**: The render method is used to display the card details within the iframe.
