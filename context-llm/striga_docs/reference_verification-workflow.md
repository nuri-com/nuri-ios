---
title: Verification Workflow
source_url: https://docs.striga.com/reference/verification-workflow
scraped_at: 2025-07-18 17:53:10
---

# Verification Workflow

Your end users must first have their email and mobile numbers verified, prior to starting KYC.

*(Find email verification too cumbersome and already maintain your own integrations for this? Let us know and we can disable this for you -[[email protected]](/cdn-cgi/l/email-protection#b0c3c5c0c0dfc2c4f0c3c4c2d9d7d19ed3dfdd))*

![](https://files.readme.io/346fb58-image.png)

Call the Start KYC API as documented previously, to obtain a SumSub token. A sample response looks like this:

striga\_start\_kyc\_res.json

```
{
  "provider": "SUMSUB",
  "token": "_act-sbx-0a8f8d92-3629-4b33-8c28-9a96bc836243",
  "userId": "009583a8-3126-4cd7-8674-6d57fe4adccf"
}
```

You can now consume the `token` from the above endpoint to use with SumSub's SDK. For example:

sumsub\_demo.js

```
function launchSumSubWebSdk(token) {
    let snsWebSdkInstance = snsWebSdk.init(
     token,
   	 // token update callback, must return Promise
   	 // Access token expired
   	 // get a new one and pass it to the callback to re-initiate the WebSDK
   	 () => this.getNewAccessToken()
    )
    .withConf({
      lang: 'en',
       onMessage: (type, payload) => {
          console.log('WebSDK onMessage', type, payload)
        },
     })
     .build();
    snsWebSdkInstance.launch('#sumsub-websdk-container') // mount sdk on div "id"
}

function getNewAccessToken() {
  return Promise.resolve(newAccessToken)// get a new token from "Start KYC" API
}

// SumSub SDK init
launchSumSubWebSdk(<SUMSUB_TOKEN>)
```

That's it! You simply need to use the SDK to start the process of verifying your user, Striga handles the rest along with SumSub. Once your user has completed verification, the result is sent via a webhook notification to your server.

> 📘
>
> ### Handling tiered KYC within your application
>
> To ensure backwards compatibility, the Tiered KYC flow will not break any existing implementation and is a feature enabled for your application if you wish to use this. However, the integration effort is straightforward in basically redirecting the user to the SumSub SDK for `currentTier` values of 1 and 2 using a new token obtained from the "Start KYC" API using the respective `tier` value.
>
> We have configured the flow on our side internally to handle the data that needs to be collected, such that you simply need to render the SumSub SDK using the token received from "Start KYC" at that Tier. Once a user has been `APPROVED` for the first time, to change Tier, the user status will change from `APPROVED` to `INITIATED`, indicating that the user must be redirected to the SumSub SDK.

## Customization

SumSub allows you to customize the default SDK using the `withConf` handler.

withConf.js

```
snsWebSdk.init(accessToken)
	// https://developers.sumsub.com/web-sdk/#frontend-integration-general
   .withConf({
        lang: 'en',
        i18n: {"document":{"subTitles":{"IDENTITY": "Upload a document that proves your identity"}}},
        uiConf: {
            // URL to css file in case you need change it dynamically from the code
            // the similar setting at Customizations tab will rewrite customCss
            customCss: "https://url.com/styles.css",
      			// you may also use to pass string with plain styles `customCssStr:`
            customCssStr: ":root {\n  --black: #000000;\n   --grey: #F5F5F5;\n  --grey-darker: #B2B2B2;\n  --border-color: #DBDBDB;\n}\n\np {\n  color: var(--black);\n  font-size: 16px;\n  line-height: 24px;\n}\n\nsection {\n  margin: 40px auto;\n}\n\ninput {\n  color: var(--black);\n  font-weight: 600;\n  outline: none;\n}\n\nsection.content {\n  background-color: var(--grey);\n  color: var(--black);\n  padding: 40px 40px 16px;\n  box-shadow: none;\n  border-radius: 6px;\n}\n\nbutton.submit,\nbutton.back {\n  text-transform: capitalize;\n  border-radius: 6px;\n  height: 48px;\n  padding: 0 30px;\n  font-size: 16px;\n  background-image: none !important;\n  transform: none !important;\n  box-shadow: none !important;\n  transition: all 0.2s linear;\n}\n\nbutton.submit {\n  min-width: 132px;\n  background: none;\n  background-color: var(--black);\n}\n\n.round-icon {\n  background-color: var(--black) !important;\n  background-image: none !important;\n}"
        },
    })
	.build();
```

When implementing using WebSDK please check [Tips & Tricks](https://developers.sumsub.com/web-sdk/#tips-tricks) by SumSub.

For more information regarding customization and implementation, please refer to SumSub's documentation:

- [WebSDK](https://developers.sumsub.com/web-sdk/)
- [Mobile SDK](https://developers.sumsub.com/msdk/)
