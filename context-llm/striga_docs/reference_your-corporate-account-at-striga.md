---
title: Your Corporate Account at Striga
source_url: https://docs.striga.com/reference/your-corporate-account-at-striga
scraped_at: 2025-07-18 17:52:23
---

# Your Corporate Account at Striga

The "Corporate" section of the Dashboard houses information about your entity and similarly on production contains a single corporate wallet that houses an account, one in each currency for your company.

![](https://files.readme.io/ae55794-image.png)

These accounts receive the proceeds of fees collected on transactional events, from your customers. Please note, we are only able to collect fee on "Deterministic Transactional Events". This basically means that if a predictable monetary event occurs, involving the account balance of a user, we can at that point in time, collect fees for you and deposit these fees into your corporate account. This way it keeps your entity out of the scope of licensing and never have to handle user funds directly. Currently we can collect fees on the following types of events -

1. Crypto Swaps (With threshold configurations)
2. Crypto Deposits/Withdrawals
3. Bank Transfers In/Out
4. Card Creation Virtual/Physical
5. Card Authorization
6. Card ATM Authorization
7. Physical Card Delivery

Most fees are set to be a flat value (in EUR) + a variable percentage value. At the time of each of the above transactional events, we automatically check the users' balance using your fee configuration and the spot exchange rate at that time, to calculate the estimated fee to be collected on your behalf and collect the fee.

![](https://files.readme.io/a651dd4-image.png)
> 📘
>
> ### Deposit Fee collection with fixed + % fees
>
> On deposit transactions, if the amount being deposited is smaller than the fixed fee, we cannot collect the fixed fee and hence only collect the percentage fee.

Fee thresholds are the fixed + percentage fee UP TO which you can change the fee to be collected from your user, at any time. This threshold applies to Crypto Exchanges mainly. However you can "Override" the applied fee at the time of a transaction, to set per transaction fees. Again, these fees for legal reasons must be lesser than or equal to the default fee configured for your application. The APIs for which you can "Override" fees are as follows -

1. Initiate Outbound LN Payment
2. Initiate SEPA Withdrawal
3. Initiate Onchain Withdrawal
4. Get Onchain Fee Estimate
5. Currency Swaps

You can request that these fees collected into your corporate account, be used to pay Striga's monthly bills, please contact your account manager at Striga for this.

## Collecting Card Authorization Fees

By default, when you configure a card authorization fee, this is a fee that will be collected from your users on every card authorization event (This includes regular E-Commerce Card Authorizations, POS Authorizations and ATM Withdrawals), when the account that the card is linked to is a non-EUR account. This is simply because it is not a norm in the EEA landscape to have authorization fees charged for using Euros.

In the case you would like to have your card authorization fees collected on those transactions where a EUR account is the debit source, you can check the box below under Settings > Fees in the portal user interface.

![](https://files.readme.io/246336cd09af9685b2c40f0dec63dd25479db8399161fca080ac91751e71e7f3-image.png)

**Note**: **Not** toggling the above box will mean that if your users make an ATM withdrawal with their card linked to a EUR account, no fees will be collected, as is the default behavior on the sandbox. If you would like to only allow collecting ATM fees for a use case where you expect your users to mainly spend with EUR linked cards, you can toggle the above and set your card authorization fees to 0. This way, fees will be collected on all ATM withdrawals irrespective of the account it is linked to and your users will not be charged any fees for card authorizations.

You can simulate ATM withdrawals (Typically MCC 6011) or other authorization scenarios on the sandbox as described in the "[Testing with Postman"](https://docs.striga.com/reference/testing-with-postman) section.
