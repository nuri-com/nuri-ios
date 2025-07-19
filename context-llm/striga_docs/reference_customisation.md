---
title: Customization
source_url: https://docs.striga.com/reference/customisation
scraped_at: 2025-07-18 17:55:31
---

# Customization

We provide customizations for embedding the UX component into your project. These will allow you to build them in a manner that meets your design requirements.

Possible customizations:

[Custom Style](#custom-style) to give you full support in replicating your design

[Hide/Unhide secret](#hideunhide-secret)to allow you to hide details from our end

[Masked card number](#custom-masked-card-number) to give your own custom masked card number format

[Custom element IDs](#custom-element-ids) to give custom element IDs rather than using our default "striga"

[Multi element supports](#rendering-multiple-elements-at-once) to help you show multiple secret in one secure instance

[Callback](#callback) to give you a response when a secret is rendered with success or error

## Custom Style

You can customize the UX component using the' style' key.

JavaScript

```
const customStyle = {
  "word-spacing": "4px",
  "font-size": "20px",
  "letter-spacing": "2px",
  color: "#fff",
  "text-align": "center",
  "font-weight": "bold",
  "@font-face": {
    "font-family": "Space Mono",
    "font-style": "normal",
    src:
      'url(https://fonts.googleapis.com/css2?family=Space+Mono:ital,wght@0,400;0,700;1,400;1,700&display=swap) format("woff2")',
    "unicode-range": "U+0400-045F, U+0490-0491, U+04B0-04B1, U+2116"
  },
  "font-family": '"Space Mono", monospace'
};

 StrigaUXPlugin.render(
    "cardNumber",
    {
      cardId: <CARD_ID>,
      style: customStyle
    }
  );
```

## Hide/Unhide secret

Using the `hideData` key, you can mask the card number.

JavaScript

```
StrigaUXPlugin.render(
    "cardNumber",
    {
      cardId: <CARD_ID>,
      hideData: Boolean,
    }
  );
```

## Custom masked card number

Using the `maskedCardNumber` key, you can provide a custom mask format.

JavaScript

```
StrigaUXPlugin.render(
    "cardNumber",
    {
      cardId: <CARD_ID>,
      hideData: Boolean,
      maskedCardNumber: "487130******1480",
    }
  );
```

## Custom element IDs

Using the `id` key, you can provide an element id.

Default value id "striga"

JavaScript

```
StrigaUXPlugin.render(
    "cvv",
    {
      id: "cvv", // element id <span id="cvv" /> 
      cardId: <CARD_ID>,
    }
  );
```

## Rendering multiple elements at once

You can also render multiple components such as the card number and the CVV using the `create` instance.

Please note that you must `await` each `render` method if you are rendering multiple elements.

JavaScript

```
StrigaUXPlugin.create('<UI_SECRET>', { applicationId: '<APPLICATION_ID>' })

await StrigaUXPlugin.render(
    "cvv",
    {
      id: "cvv", // element id <span id="cvv" /> 
      cardId: <CARD_ID>,
    }
  );

await StrigaUXPlugin.render(
    "cardNumber",
    {
      id: "card_number", // element id <span id="card_number" /> 
      cardId: <CARD_ID>,
    }
  );
```

## Callback

The callback will provide you with a response when the secrets are mounted in the elements.

The response will give you either `success` or `error`

JavaScript

```
StrigaUXPlugin.render(<KEY>, <OPTIONS>, <CALLBACK>)

StrigaUXPlugin.render(
    "cardNumber",
    {
      cardId: CARD_ID,
      hideData: Boolean,
      style: fontStyle
    },
    (data) => {
      console.log("UX CardNumber status", data); 
    }
  );
```

## Custom Copy Button Icon

You can customize the icon used for the copy button with the `copyButtonSvgIcon` key. This only has an effect if `enableCardNumberCopy` is set to true. You should provide the SVG markup as a string.

If the `copyButtonSvgIcon` is not specified, a default copy icon will be used.

JavaScript

```
StrigaUXPlugin.render(
    "cardNumber",
    {
      cardId: CARD_ID,
      hideData: Boolean,
      enableCardNumberCopy: true,
      maskedCardNumber: "487130******1480",
      copyButtonSvgIcon:`<svg width="16" height="16" viewBox="0 0 24 24" fill="#fff" xmlns="http://www.w3.org/2000/svg">
<path d="M14.5859 22H7.125C5.40182 22 4 20.5982 4 18.875V8.28906C4 6.56589 5.40182 5.16406 7.125 5.16406H14.5859C16.3091 5.16406 17.7109 6.56589 17.7109 8.28906V18.875C17.7109 20.5982 16.3091 22 14.5859 22ZM7.125 6.72656C6.26349 6.72656 5.5625 7.42755 5.5625 8.28906V18.875C5.5625 19.7365 6.26349 20.4375 7.125 20.4375H14.5859C15.4474 20.4375 16.1484 19.7365 16.1484 18.875V8.28906C16.1484 7.42755 15.4474 6.72656 14.5859 6.72656H7.125ZM20.8359 16.9219V5.125C20.8359 3.40182 19.4341 2 17.7109 2H9.03906C8.60754 2 8.25781 2.34973 8.25781 2.78125C8.25781 3.21277 8.60754 3.5625 9.03906 3.5625H17.7109C18.5724 3.5625 19.2734 4.26349 19.2734 5.125V16.9219C19.2734 17.3534 19.6232 17.7031 20.0547 17.7031C20.4862 17.7031 20.8359 17.3534 20.8359 16.9219Z" fill="#fff"/>
</svg>`

    },
    (data) => {
      if (data.isCardNumberCopied) {
          console.log("Card number copied successfully!");
      }    
		}
  );
```
