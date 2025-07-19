---
title: Testing with Postman
source_url: https://docs.striga.com/reference/testing-with-postman
scraped_at: 2025-07-18 17:52:57
---

# Testing with Postman

Try the APIs and test with our postman collection and also within the "API Credentials" section of the Portal.

# Collection

[![Postman Collection](https://upload.wikimedia.org/wikipedia/commons/c/c2/Postman_%28software%29.png)](https://storage.googleapis.com/striga-public-docs/collection.json)

[[Mirror]](https://striga-sandbox-postman.eu-central-1.linodeobjects.com/collection.json)

# Environment

[![Postman Collection](https://upload.wikimedia.org/wikipedia/commons/c/c2/Postman_%28software%29.png)](https://storage.googleapis.com/striga-public-docs/enivronment.json)

[[Mirror]](https://striga-sandbox-postman.eu-central-1.linodeobjects.com/enivronment.json)

> 📘
>
> ### Simulating Card Authorizations with varying MCCs
>
> Please use the following cURL request to simulate various card authorization scenarios -
>
> curl --location '<https://www.sandbox.striga.com/api/v1/simulate/card/authorization'>  
> --header 'api-key: <YOUR\_API\_KEY\_HERE>'  
> --header 'Content-Type: application/json'  
> --data '{  
> "cardId": "a22cebf1-a158-41b5-bc55-edbb60ff458d",  
> "amountEURCents": 1050,  
> "mcc": "6011"  
> }'
