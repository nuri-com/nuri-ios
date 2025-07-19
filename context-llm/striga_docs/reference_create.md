---
title: Create
source_url: https://docs.striga.com/reference/create
scraped_at: 2025-07-18 17:53:52
---

# Create

The create method is used to initiate the UI with the secret key and application ID. It takes two parameters:

JavaScript

```
StrigaUXPlugin.create(&lt;STRIGA_UI_SECRET&gt;, &lt;OPTIONS&gt;);
```

| Definition | Type |  |
| --- | --- | --- |
| STRIGA\_UI\_SECRET | *String* | Your UI secret for viewing sensitive data inside the iframe. |
| OPTIONS | *Object* | `applicationId`: Application id is used to identify the application. You can get this from the striga dashboard. |
