---
title: Linking Accounts
source_url: https://docs.striga.com/reference/linking-accounts
scraped_at: 2025-07-18 17:54:31
---

# Linking Accounts

When a card is created, before it can be used, there must be funds available for use. Within the Striga platform, when cards are created, they are by default linked to an account in the currency you selected when setting up your application under the `Default Card Account Currency` section as shown below -

![](https://files.readme.io/26e6aa7-linking_account.PNG)
> 🚧
>
> ### Default Card Account Currency
>
> Please note that the default currency for all cards is currently EUR (Euros). By default, for every single user, a Euro account is created as well. If this account is linked to a card, no conversion takes place and debits for card authorizations take place in Euros. However, if the account linked to a card is denominated in another platform supported currency, to the user, it appears as if card transactions are authorized against the balance held in a non-EUR currency which can be Bitcoin or another crypto currency.

When creating a card, the parameter `accountIdToLink` can be used optionally to specify an account to link this card to and this can be *any account that currently is NOT linked to another card*. When accounts are fetched, the `linkedCardId` parameter specifies either `UNLINKED` or a card ID to which that account is linked. At any given time, an account can be linked to one and one card only.

If the `accountIdToLink` parameter is not specified when creating a card, Striga automatically provisions a new Wallet entity for the user, which contains an account each for the denominations listed in the `enabledCurrencies` section of your application and then uses the `defaultCardAccountCurrency` parameter to select an account from the newly provisioned wallet to link the card to.

> 📘
>
> ### Linking multiple cards to the same account
>
> When creating a card, if the `accountIdToLink` parameter is not provided, the card will automatically be linked to the user's default wallet EUR account, or to the currency specified via the `defaultCardAccountCurrency` setting (if configured in your application). This differs from the behaviour prior to March 2025 where a new card without a specified account would automatically spawn the creation of a new wallet and the feature is entirely opt-in, meaning this will not affect any old applications that rely on this logic.
>
> If you intend to link multiple cards to a single account, please update your logic to use the `linkedCardIds` parameter of the accounts API responses which now contains an array of card IDs linked to that account.

> 🚧
>
> ### `accountIdToLink` When Collecting Fees on Card Creation
>
> If your application has fees configured for creating a card, the `accountIdToLink` parameter is mandatory when creating a card as there must be sufficient funds present in the account that will be linked to the card, to collect the fees and for your application. The account can be in any currency and the spot rate is used when collecting fees, converted from Euros.

This was designed intentionally to give you the maximum possible flexibility in providing a good user experience, whilst staying in line with card scheme requirements.
