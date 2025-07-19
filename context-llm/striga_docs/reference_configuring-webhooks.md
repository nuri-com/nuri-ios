---
title: Configuring Webhooks
source_url: https://docs.striga.com/reference/configuring-webhooks
scraped_at: 2025-07-18 17:54:58
---

# Configuring Webhooks

## Configuring a Webhook URL

Within your Striga developer account, under the "Settings" tab, you can add an endpoint where you wish to receive webhooks, as shown below.

![](https://files.readme.io/bce4c51-webhook.gif)
> 👍
>
> ### Webhook Retries
>
> Your server simply needs to respond with a status code of 2XX upon successful receipt of a webhook. Striga automatically retries sending webhooks up to 5 times until they succeed.

## Verifying Webhook Requests

All webhook requests to your server include a `signature` header that contains a value equal to creating a signature using SHA256 HMAC with your API key against the Webhook body.

You can calculate the Webhook request signature as follows, for example, using your API key and the Webhook payload:

TypeScript

```
function calculateSignature(apiKey: string, payload: any) {
  const signature = crypto.createHmac('sha256', apiKey);
  signature.update(JSON.stringify(payload));
  return signature.digest('hex');
}
```
