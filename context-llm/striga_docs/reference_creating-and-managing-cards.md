---
title: Creating and Managing Cards
source_url: https://docs.striga.com/reference/creating-and-managing-cards
scraped_at: 2025-07-18 17:53:42
---

# Creating and Managing Cards

![](https://files.readme.io/a5c3370-cards-image.png)

Once your user has passed verification, you can begin creating cards. Cards can be of two type - `VIRTUAL` and `PHYSICAL` set on the Create Card API.

For both card types, a `threeDSecurePassword` parameter is required - This must be collected from your user directly and is the password that is to be entered when the card is used for online transactions.

> 🚧
>
> ### Hosted Cards & Dedicated Cards
>
> You can create and manage cards either entirely via the API or via an iframe embedded in your application. Almost always, unless your account manager has indicated that you are eligible to use dedicated cards, you are most likely looking for the "Hosted Cards" API documentation if you are on this page - <https://docs.striga.com/reference/plug-and-play-visa-cards>
>
> Since 2025, you may manage cards with the APIs documented in the following section only once your "Hosted Cards" program has reached sufficient scale and your own branded card program is approved for go-live.
>
> Please discuss this in more detail with your account manager at Striga.

## Virtual Cards

Virtual cards once created, can be used immediately for online transactions and with Apple/Google Pay if this is enabled for your program.

As noted above, all cards are enrolled in 3D Secure by default.

![](https://files.readme.io/c87ad77-card_creation_flow.png)

## Physical Cards

When creating a card, specifying the type as `PHYSICAL` automatically creates and dispatches the card from the personalization center using the design configured for your program.

A physical card must be activated before it can be used and the last 4 digits of the card are used for this purpose and must be entered by the user into your application and then sent to the Activate Card API.

A card can be in one of the following states -

1. `CREATED` - A physical card has been created
2. `DISPATCHED`- A physical card has been manufactured and shipped
3. `ACTIVE` - A physical card has been activated using the last 4 digits of the card
4. `BLOCKED` - A physical card can be blocked intentionally or if it was lost/stolen/damaged
5. `CLOSED` - A card that has been permanently closed
6. `EXPIRED` - A card that has expired

Further, a `BLOCKED` card may have a `blockType` parameter as one of -

```
[  
  'BLOCKEDBYCARDHOLDER',  
  'BLOCKEDBYCARDHOLDERVIAPHONE',  
  'BLOCKEDBYCLIENT',  
  'BLOCKEDBYISSUER',  
  'COUNTERFEIT',  
  'FRAUDULENT',  
  'LOST',  
  'MAXINVALIDTRIESCVV2',  
  'MAXINVALIDTRIESPIN',  
  'NOTDELIVERED',  
  'STOLEN'  
]
```

To replace a card, please order a new physical card.

> ❗
>
> ### ️ Activating Physical Cards
>
> Please note that a card must be in the `DISPATCHED` state before it can be activated. Upon creation, a card is first in the `CREATED` state and various other states can be simulated using the simulator.

> 🚧
>
> ### Creating Virtual and Physical Cards
>
> A user identity can have a maximum of 10 active cards, i.e. the sum of active physical + virtual cards per user cannot exceed 10. If you would like higher limits, please contact [[email protected]](/cdn-cgi/l/email-protection#9be8eeebebf4e9efdbe8efe9f2fcfab5f8f4f6) with your case.
