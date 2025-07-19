---
title: Authenticating with the API (API Authentication)
source_url: https://docs.striga.com/reference/authenticating-with-the-api
scraped_at: 2025-07-18 17:51:52
---

# Authenticating with the API (API Authentication)

## Base URLs

Requests are made over HTTPS to the following endpoints. Please use the URLs exactly as they appear below.

| Environment | Base URL |
| --- | --- |
| Sandbox | <https://www.sandbox.striga.com/api/v1> |
| Sandbox Dashboard | <https://portal.striga.com> |
| Production | Please contact us |

## Request Headers

All API requests must be accompanied by the following headers -

| Header Parameter | description |
| --- | --- |
| api-key | Your API key as visible on your [dashboard's credential section](https://sandbox.striga.com) |
| Authorization | A signature generated using the `API Secret` [from your dashboard's credential section](https://sandbox.striga.com). More information below on generating a signature. |
| Content-Type | application/json |

> 🚧
>
> ### API Keys
>
> The sandbox and production environments mirror each other, except for the base URL and your API keys. Please contact us on [[email protected]](/cdn-cgi/l/email-protection#51222421213e2325112225233836307f323e3c) to elevate your application to production

> 👍
>
> ### Doppler
>
> We strongly recommend using a secrets manager to manage API keys and secrets. Plain text files like dotenv lead to accidental costly leaks. Use Doppler (<https://www.doppler.com/l/partner-program>) for a developer friendly experience. AWS and Google Cloud have native solutions as well.

> 📘
>
> ### Calculating HMAC on Striga v1
>
> Please note that from v1 onwards, the root of the URL that includes `/api/v1` is NOT included in the calculation of the HMAC, unlike in v0.

## Calculating your request signature

You can calculate the value of the `Authorization` header above by creating a SHA256HMAC digest (MD5) of your request body, signed with your `API Secret`, in the following manner -

1. Fetch the current UNIX timestamp

JavaScript

```
const time = Date.now().toString();
```

2. Stringify the body of your request. For Example:

JavaScript

```
const bodyString = JSON.stringify(body);

// For a GET request, please use an empty body such as:
// const bodyString = JSON.stringify({});

```

3. Calculate the hex encoded MD5 digest of your request body exactly as it will be sent. For GET requests, please include an empty body '{}' that evaluates to an MD5 of `99914b932bd37a50b983c5e7c90ae93b`.

JavaScript

```
const requestContentHexString = CryptoJS.MD5(bodyString).toString(CryptoJS.enc.Hex);

// For a GET request, the bodyString above for example would just be '{}' and the calculated MD5 is 99914b932bd37a50b983c5e7c90ae93b
```

4. Concatenate the UNIX timestamp with the request verb, path and the `requestContentHexString`

JavaScript

```
const signatureRawData = time + 'POST' + '/card/create' + requestContentHexString;
```

5. User your API Secret to create a SHA256 HMAC digest in hex

JavaScript

```
const apiSecret = '<YOUR_API_SECRET>';
const requestSignatureHexString = CryptoJS.HmacSHA256(signatureRawData, apiSecret).toString(CryptoJS.enc.Hex);
```

6. Finally, create your authorization header as follows, using the verb 'HMAC ' concatenated with the timestamp and the `requestSignatureHexString`, separated by a `:`

JavaScript

```
const authorizationHeader = 'HMAC ' + time + ':' + requestSignatureHexString;
```

Putting it all together:

TypeScript

```
import crypto from 'crypto';

const hmac = crypto.createHmac('sha256', '<YOUR_API_SECRET>');
const time = Date.now().toString();

hmac.update(time);
hmac.update('POST');
hmac.update('/ping');

const contentHash = crypto.createHash('md5');
contentHash.update(JSON.stringify({
    "dummy": 1,
    "data": 2
}));

hmac.update(contentHash.digest('hex'));

console.log(`HMAC ${time}:${hmac.digest('hex')}`);
```
