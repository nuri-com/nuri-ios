---
title: Business Onboarding Flow
source_url: https://docs.striga.com/reference/business
scraped_at: 2025-07-18 17:54:54
---

# Business Onboarding Flow

Business onboarding is similar to consumer onboarding in that an identity - a legal entity in this case - passes verification - KYB (Know Your Business) in this case - completes onboarding via the SumSub SDK implemented inside your application. Please refer to the "[KYC/KYB SDK](https://docs.striga.com/reference/kyc-sdk)" section to learn more about this.

To avoid repetition, please refer to the [onboarding flow for consumers here](https://docs.striga.com/reference/onboarding-flow). This is practically the same except the email and phone number being verified are that of the "Primary User" of the business, the registered director of the company.

As above, email verification may be handled by your application, please ensure to discuss this with your account manager at Striga if of interest.

To initiate the creation of a business account, the following information is collected through your user interface and transmitted to Striga via the APIs in the following section:

1. Company Details - Name, Incorporation Address, Registration Number, Incorporation Date, Type of Entity and Registration Country
2. Registration country (can only be one of the 31 supported countries: Austria, Belgium, Bulgaria, Croatia, Cyprus, Czech Republic, Denmark, Estonia, Finland, France, Germany, Greece, Hungary, Iceland, Ireland, Italy, Latvia, Liechtenstein, Lithuania, Luxembourg, Malta, Netherlands, Norway, Poland, Portugal, Romania, Slovakia, Slovenia, Spain, Sweden, Switzerland).
3. Primary user’s first and last name (This **must** be a registered director)
4. Primary user’s email - Email sent using your template from an email address configured by you on Striga.
5. Primary user’s phone number.

Once the above data has been collected, a business may start "KYB" using the SumSub SDK and obtaining a token from the ["Start KYB"](https://docs.striga.com/reference/post_kyb-start) API endpoint.
