---
title: Consumer Onboarding Flow
source_url: https://docs.striga.com/reference/onboarding-flow
scraped_at: 2025-07-18 17:51:59
---

# Consumer Onboarding Flow

A `user` represents a single identity which is a human being located in one of the following countries

|  |  |  |  |
| --- | --- | --- | --- |
| Austria | Belgium | Bulgaria | Croatia |
| Cyprus | Czech Republic | Denmark | Estonia |
| Finland | France | Germany | Greece |
| Hungary | Ireland | Italy | Latvia |
| Lithuania | Luxembourg | Malta | Netherlands |
| Poland | Portugal | Romania | Slovakia |
| Slovenia | Spain | Sweden | Liechtenstein |
| Norway | Iceland |  |  |

> 🚧
>
> ### GB (UK) User Onboarding
>
> Mid-2023, we suspended support for onboarding any and all new UK citizens/residents given the FCA's stance on crypto-asset companies. We're unlocking new territories and the UK is close on our roadmap, contact us on [[email protected]](/cdn-cgi/l/email-protection#93fbf6fffffcd3e0e7e1faf4f2bdf0fcfe) to learn more!

Before creating a payment account, a user must be fully onboarded and verified to comply with all applicable rules and regulations. Striga is a regulated entity and its compliance team handles the entire process of staying compliant when onboarding new users.

![](https://files.readme.io/6e27d52-image.png)

The image below illustrates the flow of creating and verifying your users before attaching payment instruments.

![](https://files.readme.io/96c1760-user-onboarding.png)

The following steps are completed in the following sequence in order to create a verified identity that is granted access to financial instruments such as IBANs, Crypto Addresses, and Cards -

1. Create a User Identity using the Create User API - This will trigger the sending of an email branded in your name to the users' email address and an SMS to the users' mobile number. You can resend the email & SMS, via the API, in case there are deliverability issues.
2. Verify the Email address of the user *(To configure email templates with your brand, please contact your Striga account manager)*
3. Verify the Mobile number of the user
4. Complete KYC via your application embedding the SumSub SDK

Once the above steps are completed, you can begin creating payment instruments for your user.

> 🚧
>
> ### SMS & Email Verification on the Sandbox
>
> To prevent spam, no actual emails or SMSs are sent while testing and the default verification code is "123456"

> 👍
>
> ### Mobile numbers on the Sandbox
>
> Please note that despite what mobile number you enter in the Create User or Patch User endpoints, the actual mobile number of the user that you would see when retrieved is different as mobile numbers are not validated on the sandbox environment and entering incorrect numbers causes service provider issues.
>
> On production, since SMS verification is performed for each user, the mobile numbers are ensured to be valid.
