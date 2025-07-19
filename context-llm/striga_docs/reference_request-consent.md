---
title: Request Consent
source_url: https://docs.striga.com/reference/request-consent
scraped_at: 2025-07-18 17:55:15
---

# Request Consent

The Request Consent method is a crucial step in ensuring secure access to card details through Striga's JavaScript UI library. It is designed to send a **One-Time Password (OTP)** to the user's **mobile number and email** for verification. This adds an extra layer of security to the process, ensuring that only authorized individuals can access sensitive card information.

The Request Consent method is also responsible for generating a `challengeId` and `dateExpires` that is used to confirm consent from the user. These values are then passed to the **Confirm Consent API**, which validates the OTP and generates an **authToken** that is used to display the card details in the iframe.

It is essential to note that every time the **Request Consent** method is called, an OTP is sent to the user's mobile number and email. Use this method only when needed, so that the user doesn't receive multiple OTPs.

Example:

```
const response = await StrigaUXPlugin.requestConsent({
    userId: USER_ID,
});

console.log(response);
// { challengeId: 'ae61a750-7300-4750-bcee-f61656b826b6', dateExpires: '2023-03-10T12:00:00Z' }
```

| Definition | Type |  |
| --- | --- | --- |
| userId | *String* | The user ID whose consent is to be obtained for displaying PAN data |
| channel | *String* | (Optional) Specifies the channel through which the OTP should be sent. Possible values are "email" and "sms". If not specified, the OTP will be sent to both the user's mobile number and email. |

In addition to the Request Consent method, three other APIs need to be integrated with your server to **confirm, resend, and revoke consent**. These APIs ensure that you have complete control over who can access sensitive card information and allows you to revoke access quickly if necessary.

1. **[Confirm Consent](/reference/confirm-consent-ui)**: This API is used to confirm the consent obtained from the user, validate the OTP, and obtain the authToken required to view the card details securely. To confirm consent, you need to send a POST request to the API with the following parameters in the request body:

```
{
    "userId": "{{user_id}}",
    "challengeId": "ae61a750-7300-4750-bcee-f61656b826b6",
    "verificationCode": "123456"
}
```

The API returns a response containing the **cardAuthToken**, which can be passed into `render` methods as `authToken` to display sensitive information.

2. **[Resend Consent](/reference/resend-consent-code-ui)**: This API is used to resend the OTP to the user's mobile number and email address in case the user did not receive it or if the OTP expired. To resend consent, you need to send a POST request to the API with the following parameters in the request body:

```
{
    "userId": "{{user_id}}",
    "challengeId" : "{{challenge_id}}"
}
```

3. **[Revoke Consent](/reference/revoke-consent-ui)**: This API is used to invalidate the authToken obtained using the Request Consent method. If you want to revoke access to the card details, you can call this API to invalidate the authToken.

```
{
    "userId": "{{user_id}}"
}
```

**Security Measures**

To ensure the security of PAN data, Striga's JavaScript UI library implements several measures:

1. The card details are never transmitted to your server, ensuring that you qualify for the lowest level of PCI compliance.
2. The card details can only be accessed using the **authToken** obtained via the **Request Consent method**, which ensures that only authorized users can view PAN data.
3. The authToken obtained using the Request Consent method is valid only for **24 Hours**, ensuring that card details are not accessible indefinitely.
