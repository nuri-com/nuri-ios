---
title: JS HMAC Sample Snippet
source_url: https://docs.striga.com/reference/js-hmac-sample-snippet
scraped_at: 2025-07-18 17:51:32
---

# JS HMAC Sample Snippet

Below is a simple JavaScript snippet that you can run in your browser to test the HMAC authentication flow using your API Key and Secret. A GET request where no body is sent is shown below as an example with node-fetch.

> 📘
>
> ### Calculating HMAC on Striga v1
>
> Please note that from v1 onwards, the root of the URL that includes `/api/v1` is NOT included in the calculation of the HMAC, unlike in v0.

JavaScript

```
const crypto = require('crypto');
const fetch = require('node-fetch');

const SANDBOX_API_KEY = '<YOUR-API-KEY>';
const SANDBOX_API_SECRET = '<YOUR-API-SECRET>';
const API_BASE_URL = 'https:/www.sandbox.striga.com/api/v1';
const TEST_ENDPOINT = '/user/<USER-ID>';
const method = 'GET';

const calcSig = (body) => {
  const hmac = crypto.createHmac('sha256', SANDBOX_API_SECRET);
  const time = Date.now().toString();

  hmac.update(time);
  hmac.update(method);
  hmac.update(TEST_ENDPOINT);

  const contentHash = crypto.createHash('md5');
  contentHash.update(JSON.stringify(body));

  hmac.update(contentHash.digest('hex'));

  const auth = `HMAC ${time}:${hmac.digest('hex')}`;

  return auth;
};

const sendRequest = async () => {
  try {
    const body = {};
    const headers = {
      authorization: calcSig(body),
      'api-key': SANDBOX_API_KEY,
      'Content-Type': 'application/json',
    };
    const f = {
      method,
      headers,
    };
    const fullURL = `${API_BASE_URL}${TEST_ENDPOINT}`;
    const response = await fetch(fullURL, f);
    if (response.ok) console.log(await response.text());
    else console.log(response.status);
  } catch (err) {
    console.error('Fetch error = ', err);
  }
};

sendRequest();
```
