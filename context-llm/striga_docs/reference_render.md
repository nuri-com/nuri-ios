---
title: Render
source_url: https://docs.striga.com/reference/render
scraped_at: 2025-07-18 17:55:44
---

# Render

The render method is used to display the card details in the iframe. It takes four parameters:

**cardNumber, cvv, 3ds or pin**: *The type of card detail to display.*

**Options**: *An object containing the card details and other options.*

**Callback**: *A function that is called when the iframe is loaded or an error occurs.*

The options object can include the following properties:

**cardId**: *The unique identifier for the card.*

**hideData**: *A boolean value indicating whether to hide sensitive data.*

**authToken**: *The authentication token for the user.*

**maskedCardNumber**: *The masked card number to display.*

**style**: *An object containing CSS styles to apply to the iframe.*

**enableCardNumberCopy**: *A boolean value indicating whether the card number should be allowed to be copied to clipboard. If set to true, a copy button will be displayed.*

**copyButtonSvgIcon**: *An SVG icon that will be used for the copy button. This property only has effect if enableCardNumberCopy is set to true. The value should be a string containing the SVG markup.*

*Note: Create separate render methods to render each of the sensitive components to be displayed, by creating a new instance of`StrigaUXPlugin`*

JavaScript

```
StrigaUXPlugin.render(<KEY>, <OPTIONS>, <CALLBACK>)
```

| Definition | Type |  |
| --- | --- | --- |
| KEY | *String* | `cardNumber`  `cvv`  `pin`  `3ds` |
| OPTIONS | *Object* | `cardId`  `authToken`  `style`  `hideData`  `id`  `maskedCardNumber`  `enableCardNumberCopy`  `copyButtonSvgIcon`  Check customisation for more details. |
| CALLBACK | *Function* | Response *Object*: `success` or `error` |

![](https://files.readme.io/a5b4331-IMG_1717.jpg)

## Card number

JavaScript

```
StrigaUXPlugin.render("cardNumber", {cardId: '<CARD_ID>', authToken: '<CARD_AUTH_TOKEN>'})
```

## CVV

JavaScript

```
StrigaUXPlugin.render("cvv", {cardId: '<CARD_ID>', authToken: '<CARD_AUTH_TOKEN>'})
```

## Card PIN

*Only activated**PHYSICAL** card has a card PIN.*

JavaScript

```
StrigaUXPlugin.render("pin", {cardId: '<CARD_ID>', authToken: '<CARD_AUTH_TOKEN>'})
```

## 3D Secure Password

JavaScript

```
StrigaUXPlugin.render("3ds", {cardId: '<CARD_ID>', authToken: '<CARD_AUTH_TOKEN>'})
```

## Copy card number

You can only copy the card number if enableCardNumberCopy is set to true. When the card number is copied, the callback function receives an event object containing the key isCardNumberCopied. This key will be set to true when the user successfully copies the card number.  
This allows developers to implement additional behaviour, such as displaying a success message.

JavaScript

```
StrigaUXPlugin.render(
    "cardNumber",
    {
      cardId: 'CARD_ID',
      enableCardNumberCopy: true,
    },
    (data) => {
      if (data.isCardNumberCopied) {
          console.log("Card number copied successfully!");
      }    
		}
  );
```
