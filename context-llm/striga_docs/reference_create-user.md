---
title: Create User
source_url: https://docs.striga.com/reference/create-user
scraped_at: 2025-07-18 17:51:54
---

# Create User

Users are identities representing individuals. Once on-boarded, users can create accounts and cards.

> 🚧
>
> ### IMPORTANT:
>
> Creating a user identity immediately sends out the verification emails and SMS's which are sent automatically on the PATCH User API as well depending upon the verification status of the email address and/or mobile number. It is a known fraud exploited by scammers to spam your "Create User" API with invalid email addresses and mobile numbers to add unnecessarily large charges to your bill (More info. here - <https://www.twilio.com/docs/verify/preventing-toll-fraud#what-is-sms-pumping>)
>
> SMS charges are passed on at cost to you and we strongly recommend adding an additional layer or protection within your "Create User" flow on your frontend to prevent illicit access to your API. Email bounces further hurts your domain reputation, although charges may be lesser in these cases.
