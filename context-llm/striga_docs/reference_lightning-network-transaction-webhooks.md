---
title: Lightning Network Transaction Webhooks
source_url: https://docs.striga.com/reference/lightning-network-transaction-webhooks
scraped_at: 2025-07-18 17:50:23
---

# Lightning Network Transaction Webhooks

### Lightning Transaction Webhooks

For example, when a lightning deposit is credited -

JSON

```
{
  "type": "LN_INCOMING_CONFIRMED",
  "id": "389e95b7-66c0-4102-8a8a-ee2dbf1e93e2",
  "accountId": "7556347639b1cb6a0f1fc7360b14ea31",
  "syncedOwnerId": "01f16ac1-0934-4c4a-a71f-9c2215bb9205",
  "sourceSyncedOwnerId": "01f16ac1-0934-4c4a-a71f-9c2215bb9205",
  "credit": "10000",
  "timestamp": "2023-08-21T13:46:48.683Z",
  "txType": "LN_INCOMING_CONFIRMED",
  "memo": "partnerships",
  "otherCryptoIdentifier": "lntb100u1pjwx646pp53cnl8l2cv3g8sg8mdvmasde8lye346nvz3rts2mqj49gp2ch40fsdq5wpshyarwv4e8x6rfwpescqzzsxqyzjpqsp5swem9k8a9xf67sgasq05pd5gfffp8d0ngkct48tkyzwh39yapwvs9qyyssqw9lht0jsc9kp9hwgk6ch8ly5mj3jguyvxdseenrafhnz274xk2ayeecnauv97x7e90j44y4vd9kww4amwmjr52fcaw4eepkt6xsrgdgqp28mlt",
  "strigaFee": "100",
  "strigaFeeCurrency": "BTC",
  "exchangeRate": "23904.6",
  "balanceBefore": {
    "amount": "900",
    "currency": "satoshis"
  },
  "balanceAfter": {
    "amount": "10900",
    "currency": "satoshis"
  }
}

{
  "type": "LN_OUTGOING_DENIED",
  "id": "2b488642-479d-4237-865f-005531c78ecd",
  "accountId": "ebe221f983c4c2b8ef00e6a622f8839f",
  "syncedOwnerId": "4a3ad895-8347-4b45-b0ee-4d24b5f76f35",
  "sourceSyncedOwnerId": "4a3ad895-8347-4b45-b0ee-4d24b5f76f35",
  "credit": "12",
  "timestamp": "2023-01-03T14:55:15.845Z",
  "txType": "LN_OUTGOING_DENIED",
  "memo": "lntb110n1p3mgsy7pp5j0tydwwwt79s2spz3r2pgmnzu4ckk2ds4quzudtpk22g9z6wtmnsdqqcqzpgxqyz5vqsp5vmd53ytfx88l0jxqaxuv8l2rcn65hlrl29n4qurg8tj6lhds4jpq9qyyssqy9cm2vr6e8k6hu56m7yqxa6kz6sms99cwpjcjz3x2wp7dn7utpqsxt8t7afw7w4fc5v54l6rlczr9vqqnvdwzhfh83l9evstpya0uuspfrlh64",
  "otherCryptoIdentifier": "lntb110n1p3mgsy7pp5j0tydwwwt79s2spz3r2pgmnzu4ckk2ds4quzudtpk22g9z6wtmnsdqqcqzpgxqyz5vqsp5vmd53ytfx88l0jxqaxuv8l2rcn65hlrl29n4qurg8tj6lhds4jpq9qyyssqy9cm2vr6e8k6hu56m7yqxa6kz6sms99cwpjcjz3x2wp7dn7utpqsxt8t7afw7w4fc5v54l6rlczr9vqqnvdwzhfh83l9evstpya0uuspfrlh64",
  "strigaFee": "1",
  "strigaFeeCurrency": "BTC",
  "exchangeRate": "15773",
  "balanceBefore": {
    "amount": "813218666",
    "currency": "satoshis"
  },
  "balanceAfter": {
    "amount": "813218678",
    "currency": "satoshis"
  }
}

```

For example, when a lightning invoice is paid -

JSON

```
{
  "type": "LN_OUTGOING_INITIATED",
  "id": "dfb05043-3695-4267-92dc-aebbf95c6ec9",
  "accountId": "7556347639b1cb6a0f1fc7360b14ea31",
  "syncedOwnerId": "01f16ac1-0934-4c4a-a71f-9c2215bb9205",
  "sourceSyncedOwnerId": "01f16ac1-0934-4c4a-a71f-9c2215bb9205",
  "debit": "1010",
  "timestamp": "2023-08-21T13:48:15.851Z",
  "txType": "LN_OUTGOING_INITIATED",
  "memo": "lntb10u1pjwx6cxpp5pzvpqt54ykzhccvl3sn48q3f8m9k3x68jmncm6j3wqrr2s794f9sdqqcqzzsxqyz5vqsp5utsn5vus44hvjhpjmmd87pwzpzkm5jjp00apsstff3ehxexx7rmq9qyyssqnttagqeppspyl6mu9s80u2s28r49vfp3cg8uckwasftpfmmaysfxruvjd8hwp3wgdxwqnk8867eqld7a0yeq9e2p6vktxe79pdkynnsqpn990j",
  "otherCryptoIdentifier": "lntb10u1pjwx6cxpp5pzvpqt54ykzhccvl3sn48q3f8m9k3x68jmncm6j3wqrr2s794f9sdqqcqzzsxqyz5vqsp5utsn5vus44hvjhpjmmd87pwzpzkm5jjp00apsstff3ehxexx7rmq9qyyssqnttagqeppspyl6mu9s80u2s28r49vfp3cg8uckwasftpfmmaysfxruvjd8hwp3wgdxwqnk8867eqld7a0yeq9e2p6vktxe79pdkynnsqpn990j",
  "strigaFee": "10",
  "strigaFeeCurrency": "BTC",
  "exchangeRate": "23900",
  "balanceBefore": {
    "amount": "9766",
    "currency": "satoshis"
  },
  "balanceAfter": {
    "amount": "8756",
    "currency": "satoshis"
  }
}
```

JSON

```
{
  "type": "LN_OUTGOING_CONFIRMED",
  "id": "dfb05043-3695-4267-92dc-aebbf95c6ec9",
  "accountId": "7556347639b1cb6a0f1fc7360b14ea31",
  "syncedOwnerId": "01f16ac1-0934-4c4a-a71f-9c2215bb9205",
  "sourceSyncedOwnerId": "01f16ac1-0934-4c4a-a71f-9c2215bb9205",
  "timestamp": "2023-08-21T13:48:15.881Z",
  "txType": "LN_OUTGOING_CONFIRMED",
  "memo": "undefined",
  "otherCryptoIdentifier": "lntb10u1pjwx6cxpp5pzvpqt54ykzhccvl3sn48q3f8m9k3x68jmncm6j3wqrr2s794f9sdqqcqzzsxqyz5vqsp5utsn5vus44hvjhpjmmd87pwzpzkm5jjp00apsstff3ehxexx7rmq9qyyssqnttagqeppspyl6mu9s80u2s28r49vfp3cg8uckwasftpfmmaysfxruvjd8hwp3wgdxwqnk8867eqld7a0yeq9e2p6vktxe79pdkynnsqpn990j",
  "exchangeRate": "23900",
  "balanceBefore": {
    "amount": "8756",
    "currency": "satoshis"
  },
  "balanceAfter": {
    "amount": "8756",
    "currency": "satoshis"
  }
}
```
