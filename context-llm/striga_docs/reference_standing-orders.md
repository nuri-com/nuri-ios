---
title: Automated Swaps & Withdrawals
source_url: https://docs.striga.com/reference/standing-orders
scraped_at: 2025-07-18 17:51:25
---

# Automated Swaps & Withdrawals

A standing order on Striga allows your application to build simpler on-ramp flows while remaining out of scope of MiCA compliance. You can -

1. Create a standing order using the [Create Standing Order API](https://docs.striga.com/reference/post_create), which will initiate an OTP to be sent to the user (SMS and/or email - using your pre-verified email address on Striga).
   1. When creating a standing order you need to specify a **fiat** (EUR) account ID which must be [enriched](https://docs.striga.com/reference/enrich-account) with an IBAN. This is the account that will be monitored for incoming fiat payments to be automatically converted and paid out.
   2. When creating a standing order, you need to pass in a whitelisted address ID (Please refer to the [Whitelist Address API](https://docs.striga.com/reference/whitelist-destination-address)). Fiat will be converted into this currency and paid out to this address.
2. [Confirm a standing order](https://docs.striga.com/reference/post_confirm) by passing along the OTP that the user entered into your application. Once confirmed, the Standing Order will have an `ACTIVE` status and any incoming fiat is automatically converted into the currency of the destination address and paid out.
3. [Cancel a standing order](https://docs.striga.com/reference/post_confirm) by passing in a user ID. This will initiate an OTP, same as above, to be used in the Confirm endpoint, same as above. This will update a standing order status to `CANCELLED`.
4. Modify or Update a standing order by simply creating a new one. This will automatically cancel the last active one.

> 📘
>
> ### Standing Order Parameters
>
> 1. There are no limits to swapping funds but depending upon the KYC tier of a user, there may be a withdrawal limit. If during a standing order, the swap is successful but a withdrawal would exceed the users' limits, the withdrawal does not take place. Your user interface may redirect the user to complete the next Tier of KYC to unlock higher limits after which you can use the "Resume Standing Order" API.
> 2. The ["Resume Standing Order"](https://docs.striga.com/reference/post_resume) API can also be used to force run a standing order if it failed for whatever reason. It will -
>    1. Check if the user has an active standing order
>    2. Check if the user has any fiat funds in the source fiat account ID specified when creating the standing order. If yes, It will swap funds into the destination currency, provided it is above the minimum tradeable value.
>    3. Check if there is are any virtual assets to be withdrawn in the destination account of the same wallet as the fiat account.
>    4. Check if a withdrawal can be made by checking the users' limits and checking network fees.
>    5. If both above checks pass, an on chain transaction is sent.

Webhooks are sent in an identical format to the swap and withdrawal webhooks if you did this manually. The primary difference is that with a single OTP confirmation, a user can set up a recurring order to buy a crypto-currency and send it on-chain immediately.

> 🚧
>
> ### Testing Standing Orders on the Sandbox
>
> To test the full flow of standing orders on the sandbox, you must have a valid "testnet" balance of the coin you are testing the standing order with. Testnet coins are hard to come by at times and since EUR on the sandbox is entirely fictional, trading fictional EUR into a real testnet coin and withdrawing it on chain would not be feasible on the sandbox.
>
> We recommend creating one separate wallet on the sandbox to deposit testnet coins and then testing standing orders on another wallet. When attempting to execute an on-chain withdrawal at the end of a standing order flow on the sandbox, the users' "Testnet Balance" is checked which is the sum of all on-chain + LN deposits minus the sum of all on-chain + LN withdrawals.

We recommend using a separate "[Wallet](https://docs.striga.com/reference/storing-value)" object within Striga dedicated for Standing Orders such that you can still use another "Wallet" for cards, IBANs, one-off on-ramps and off-ramps or whatever other use case you have in mind.

An example of the standing orders object -

JSON

```
{
    "orders": [
        {
            "id": "f3939d43-ae5c-4104-a5cf-c02b4f40c062",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "ACTIVE",
            "currency": "BTC",
            "network": {
                "name": "Bitcoin Testnet 3"
            },
            "address": "2Mwe921reL6yKoMtzf2wCfdE5XiyEfazzb9",
            "whitelistedAddressId": "3fadebcb-4d5c-4bd0-b7fe-76f6fe77d3ab",
            "createdAt": "2024-08-30T08:02:24.548Z",
            "swaps": [],
            "payouts": []
        },
        {
            "id": "ef68f573-8a9c-4a26-85c3-eed75f289e03",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "BTC",
            "network": {
                "name": "Bitcoin Testnet 3"
            },
            "address": "2Mwe921reL6yKoMtzf2wCfdE5XiyEfazzb9",
            "whitelistedAddressId": "3fadebcb-4d5c-4bd0-b7fe-76f6fe77d3ab",
            "createdAt": "2024-08-30T07:50:44.534Z",
            "swaps": [
                {
                    "id": "430e9b1f-26a3-4e95-ae68-8b915c016f79",
                    "accountId": "ba5967d486a25dfeefe9e5c939164977",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "destinationSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "credit": "1837683",
                    "timestamp": "2024-08-30T07:50:56.812Z",
                    "txType": "EXCHANGE_CREDIT",
                    "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
                    "memo": "Swap 989 EUR to BTC",
                    "memoPayer": "STANDING_ORDER_ef68f573-8a9c-4a26-85c3-eed75f289e03",
                    "currency": "BTC",
                    "exchangeRate": "1",
                    "order": {
                        "price": "53817.75",
                        "debit": {
                            "currency": "EUR",
                            "amountFloat": "989",
                            "amount": "98900"
                        },
                        "credit": {
                            "currency": "BTC",
                            "amountFloat": "0.01837683",
                            "amount": "1837683"
                        }
                    },
                    "balanceBefore": {
                        "amount": "0",
                        "balance": "0",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "1837683",
                        "balance": "1837683",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "1100",
                        "networkFee": "0",
                        "ourFee": "0",
                        "theirFee": "1100",
                        "feeCurrency": "EUR",
                        "fixedFeeDetails": {
                            "amount": "100",
                            "exchangeRate": "1",
                            "appliedFeeCents": "100"
                        },
                        "percentageFeeDetails": {
                            "amount": "1000",
                            "appliedFeeBps": "100"
                        }
                    }
                }
            ],
            "payouts": [
                {
                    "id": "2feb446e-9673-46ab-b734-f7d7dfc47dbe",
                    "accountId": "ba5967d486a25dfeefe9e5c939164977",
                    "syncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "debit": "1683675",
                    "timestamp": "2024-08-30T07:51:09.602Z",
                    "txType": "ON_CHAIN_WITHDRAWAL_INITIATED",
                    "memo": "ON_CHAIN_WITHDRAWAL_INITIATED 0.01683675 BTC 2feb446e-9673-46ab-b734-f7d7dfc47dbe",
                    "currency": "BTC",
                    "exchangeRate": "53550.1",
                    "balanceBefore": {
                        "amount": "1837683",
                        "balance": "1837683",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "154008",
                        "balance": "154008",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "154008",
                        "networkFee": "154008",
                        "ourFee": "154008",
                        "theirFee": "0",
                        "feeCurrency": "BTC",
                        "feePerByte": "46",
                        "fixedFeeDetails": {
                            "amount": "0",
                            "exchangeRate": "0"
                        },
                        "percentageFeeDetails": {
                            "amount": "0"
                        }
                    },
                    "blockchainNetwork": "Bitcoin Testnet 3"
                }
            ]
        },
        {
            "id": "505fcf9d-04f6-4f46-854a-1ce64e858891",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "BTC",
            "network": {
                "name": "Bitcoin Testnet 3"
            },
            "address": "2Mwe921reL6yKoMtzf2wCfdE5XiyEfazzb9",
            "whitelistedAddressId": "3fadebcb-4d5c-4bd0-b7fe-76f6fe77d3ab",
            "createdAt": "2024-08-30T07:33:11.264Z",
            "swaps": [
                {
                    "id": "15e0c226-fee6-427d-a6ce-e7788e1c254a",
                    "accountId": "ba5967d486a25dfeefe9e5c939164977",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "destinationSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "credit": "181659",
                    "timestamp": "2024-08-30T07:33:29.204Z",
                    "txType": "EXCHANGE_CREDIT",
                    "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
                    "memo": "Swap 98 EUR to BTC",
                    "memoPayer": "STANDING_ORDER_505fcf9d-04f6-4f46-854a-1ce64e858891",
                    "currency": "BTC",
                    "exchangeRate": "1",
                    "order": {
                        "price": "53947.2",
                        "debit": {
                            "currency": "EUR",
                            "amountFloat": "98",
                            "amount": "9800"
                        },
                        "credit": {
                            "currency": "BTC",
                            "amountFloat": "0.00181659",
                            "amount": "181659"
                        }
                    },
                    "balanceBefore": {
                        "amount": "0",
                        "balance": "0",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "181659",
                        "balance": "181659",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "200",
                        "networkFee": "0",
                        "ourFee": "0",
                        "theirFee": "200",
                        "feeCurrency": "EUR",
                        "fixedFeeDetails": {
                            "amount": "100",
                            "exchangeRate": "1",
                            "appliedFeeCents": "100"
                        },
                        "percentageFeeDetails": {
                            "amount": "100",
                            "appliedFeeBps": "100"
                        }
                    }
                },
                {
                    "id": "742375fb-6160-4521-8872-df103dd9e266",
                    "accountId": "ba5967d486a25dfeefe9e5c939164977",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "destinationSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "credit": "181922",
                    "timestamp": "2024-08-30T07:40:22.909Z",
                    "txType": "EXCHANGE_CREDIT",
                    "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
                    "memo": "Swap 98 EUR to BTC",
                    "memoPayer": "STANDING_ORDER_505fcf9d-04f6-4f46-854a-1ce64e858891",
                    "currency": "BTC",
                    "exchangeRate": "1",
                    "order": {
                        "price": "53869.11",
                        "debit": {
                            "currency": "EUR",
                            "amountFloat": "98",
                            "amount": "9800"
                        },
                        "credit": {
                            "currency": "BTC",
                            "amountFloat": "0.00181922",
                            "amount": "181922"
                        }
                    },
                    "balanceBefore": {
                        "amount": "181659",
                        "balance": "181659",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "363581",
                        "balance": "363581",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "200",
                        "networkFee": "0",
                        "ourFee": "0",
                        "theirFee": "200",
                        "feeCurrency": "EUR",
                        "fixedFeeDetails": {
                            "amount": "100",
                            "exchangeRate": "1",
                            "appliedFeeCents": "100"
                        },
                        "percentageFeeDetails": {
                            "amount": "100",
                            "appliedFeeBps": "100"
                        }
                    }
                }
            ],
            "payouts": [
                {
                    "id": "6aa75419-d9a7-43ca-9707-461fdf8c0e40",
                    "accountId": "ba5967d486a25dfeefe9e5c939164977",
                    "syncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "debit": "229661",
                    "timestamp": "2024-08-30T07:40:41.180Z",
                    "txType": "ON_CHAIN_WITHDRAWAL_INITIATED",
                    "memo": "ON_CHAIN_WITHDRAWAL_INITIATED 0.00229661 BTC 6aa75419-d9a7-43ca-9707-461fdf8c0e40",
                    "currency": "BTC",
                    "exchangeRate": "53601.4",
                    "balanceBefore": {
                        "amount": "363581",
                        "balance": "363581",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "133920",
                        "balance": "133920",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "133920",
                        "networkFee": "133920",
                        "ourFee": "133920",
                        "theirFee": "0",
                        "feeCurrency": "BTC",
                        "feePerByte": "40",
                        "fixedFeeDetails": {
                            "amount": "0",
                            "exchangeRate": "0"
                        },
                        "percentageFeeDetails": {
                            "amount": "0"
                        }
                    },
                    "blockchainNetwork": "Bitcoin Testnet 3"
                }
            ]
        },
        {
            "id": "47511b54-c3d7-4167-a563-d08189584e97",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "BTC",
            "network": {
                "name": "Bitcoin Testnet 3"
            },
            "address": "2Mwe921reL6yKoMtzf2wCfdE5XiyEfazzb9",
            "whitelistedAddressId": "3fadebcb-4d5c-4bd0-b7fe-76f6fe77d3ab",
            "createdAt": "2024-08-30T07:04:40.627Z",
            "swaps": [
                {
                    "id": "fb901818-481b-4de2-813d-26eed3e65095",
                    "accountId": "9fe16dc13dbc0a53587719429bd55529",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "destinationSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "credit": "235365",
                    "timestamp": "2024-08-30T07:07:02.587Z",
                    "txType": "EXCHANGE_CREDIT",
                    "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
                    "memo": "Swap 126.63 EUR to BTC",
                    "memoPayer": "STANDING_ORDER_47511b54-c3d7-4167-a563-d08189584e97",
                    "currency": "BTC",
                    "exchangeRate": "1",
                    "order": {
                        "price": "53801.37",
                        "debit": {
                            "currency": "EUR",
                            "amountFloat": "126.63",
                            "amount": "12663"
                        },
                        "credit": {
                            "currency": "BTC",
                            "amountFloat": "0.00235365",
                            "amount": "235365"
                        }
                    },
                    "balanceBefore": {
                        "amount": "5222632",
                        "balance": "5222632",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "5457997",
                        "balance": "5457997",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "0",
                        "networkFee": "0",
                        "ourFee": "0",
                        "theirFee": "0",
                        "feeCurrency": "EUR",
                        "fixedFeeDetails": {
                            "amount": "0",
                            "exchangeRate": "0"
                        },
                        "percentageFeeDetails": {
                            "amount": "0"
                        }
                    }
                }
            ],
            "payouts": []
        },
        {
            "id": "1a36a72b-0609-4279-b104-69fb0aa1f176",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "BTC",
            "network": {
                "name": "Bitcoin Testnet 3"
            },
            "address": "2Mwe921reL6yKoMtzf2wCfdE5XiyEfazzb9",
            "whitelistedAddressId": "3fadebcb-4d5c-4bd0-b7fe-76f6fe77d3ab",
            "createdAt": "2024-08-29T13:30:55.198Z",
            "swaps": [
                {
                    "id": "4a087732-d0de-4515-ae25-f7b3e9308375",
                    "accountId": "9fe16dc13dbc0a53587719429bd55529",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "destinationSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "credit": "181093",
                    "timestamp": "2024-08-29T13:31:06.563Z",
                    "txType": "EXCHANGE_CREDIT",
                    "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
                    "memo": "Swap 99 EUR to BTC",
                    "memoPayer": "STANDING_ORDER_1a36a72b-0609-4279-b104-69fb0aa1f176",
                    "currency": "BTC",
                    "exchangeRate": "1",
                    "order": {
                        "price": "54667.78",
                        "debit": {
                            "currency": "EUR",
                            "amountFloat": "99",
                            "amount": "9900"
                        },
                        "credit": {
                            "currency": "BTC",
                            "amountFloat": "0.00181093",
                            "amount": "181093"
                        }
                    },
                    "balanceBefore": {
                        "amount": "91539",
                        "balance": "91539",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "272632",
                        "balance": "272632",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "100",
                        "networkFee": "0",
                        "ourFee": "0",
                        "theirFee": "100",
                        "feeCurrency": "EUR",
                        "fixedFeeDetails": {
                            "amount": "0",
                            "exchangeRate": "1",
                            "appliedFeeCents": "0"
                        },
                        "percentageFeeDetails": {
                            "amount": "100",
                            "appliedFeeBps": "100"
                        }
                    }
                }
            ],
            "payouts": []
        },
        {
            "id": "6dcf3360-e8e5-4228-af12-0d58267e6999",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "BTC",
            "network": {
                "name": "Bitcoin Testnet 3"
            },
            "address": "2Mwe921reL6yKoMtzf2wCfdE5XiyEfazzb9",
            "whitelistedAddressId": "3fadebcb-4d5c-4bd0-b7fe-76f6fe77d3ab",
            "createdAt": "2024-08-29T13:25:31.312Z",
            "swaps": [
                {
                    "id": "9f5c07ef-59de-453f-802f-dc1e4c8b24fe",
                    "accountId": "9fe16dc13dbc0a53587719429bd55529",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "destinationSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "credit": "90539",
                    "timestamp": "2024-08-29T13:25:41.838Z",
                    "txType": "EXCHANGE_CREDIT",
                    "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
                    "memo": "Swap 49.5 EUR to BTC",
                    "memoPayer": "STANDING_ORDER_6dcf3360-e8e5-4228-af12-0d58267e6999",
                    "currency": "BTC",
                    "exchangeRate": "1",
                    "order": {
                        "price": "54672",
                        "debit": {
                            "currency": "EUR",
                            "amountFloat": "49.5",
                            "amount": "4950"
                        },
                        "credit": {
                            "currency": "BTC",
                            "amountFloat": "0.00090539",
                            "amount": "90539"
                        }
                    },
                    "balanceBefore": {
                        "amount": "1000",
                        "balance": "1000",
                        "currency": "satoshis"
                    },
                    "balanceAfter": {
                        "amount": "91539",
                        "balance": "91539",
                        "currency": "satoshis"
                    },
                    "feeEstimate": {
                        "totalFee": "50",
                        "networkFee": "0",
                        "ourFee": "0",
                        "theirFee": "50",
                        "feeCurrency": "EUR",
                        "fixedFeeDetails": {
                            "amount": "0",
                            "exchangeRate": "1",
                            "appliedFeeCents": "0"
                        },
                        "percentageFeeDetails": {
                            "amount": "50",
                            "appliedFeeBps": "100"
                        }
                    }
                }
            ],
            "payouts": []
        },
        {
            "id": "d4a7c820-c7f1-48f5-87db-a2f6c22238ff",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "USDC",
            "network": {
                "name": "USD Coin Test (Amoy Polygon)",
                "type": "ERC20",
                "contractAddress": "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582"
            },
            "address": "0x9E8b059878F1b384aCF9fF26b0e87D5899C19d81",
            "whitelistedAddressId": "720781a9-474a-4fdc-b35b-dd3cdd964b37",
            "createdAt": "2024-08-29T11:47:39.385Z",
            "swaps": [
                {
                    "id": "3aacb5b9-948b-47ad-80e0-f527d86cc85a",
                    "accountId": "0a34106246314a251515c07475852e04",
                    "sourceSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "destinationSyncedOwnerId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
                    "credit": "2690",
                    "timestamp": "2024-08-29T12:53:25.813Z",
                    "txType": "EXCHANGE_CREDIT",
                    "txSubType": "CURRENCY_EXCHANGE_CONFIRMED",
                    "memo": "Swap 24.75 EUR to USDC",
                    "memoPayer": "STANDING_ORDER_d4a7c820-c7f1-48f5-87db-a2f6c22238ff",
                    "currency": "USDC",
                    "exchangeRate": "1",
                    "order": {
                        "price": "0.92",
                        "debit": {
                            "currency": "EUR",
                            "amountFloat": "24.75",
                            "amount": "2475"
                        },
                        "credit": {
                            "currency": "USDC",
                            "amountFloat": "26.9",
                            "amount": "2690"
                        }
                    },
                    "balanceBefore": {
                        "amount": "2152",
                        "balance": "2152",
                        "currency": "cents"
                    },
                    "balanceAfter": {
                        "amount": "4842",
                        "balance": "4842",
                        "currency": "cents"
                    },
                    "feeEstimate": {
                        "totalFee": "25",
                        "networkFee": "0",
                        "ourFee": "0",
                        "theirFee": "25",
                        "feeCurrency": "EUR",
                        "fixedFeeDetails": {
                            "amount": "0",
                            "exchangeRate": "1",
                            "appliedFeeCents": "0"
                        },
                        "percentageFeeDetails": {
                            "amount": "25",
                            "appliedFeeBps": "100"
                        }
                    }
                }
            ],
            "payouts": []
        },
        {
            "id": "81644df7-acdc-493f-bc92-b95b4a11f1af",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "USDC",
            "network": {},
            "whitelistedAddressId": "720781a9-474a-4fdc-b35b-dd3cdd964b37",
            "createdAt": "2024-08-29T11:39:01.970Z",
            "swaps": [],
            "payouts": []
        },
        {
            "id": "6302de13-167a-4f0f-a3c0-95b93152c25c",
            "userId": "cf10a48b-32c5-4c7f-a0fd-f8215cad9d5b",
            "status": "CANCELLED",
            "currency": "USDC",
            "network": {
                "name": "USD Coin Test (Amoy Polygon)",
                "type": "ERC20",
                "contractAddress": "0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582"
            },
            "address": "0x9E8b059878F1b384aCF9fF26b0e87D5899C19d81",
            "whitelistedAddressId": "720781a9-474a-4fdc-b35b-dd3cdd964b37",
            "createdAt": "2024-08-29T11:37:43.670Z",
            "swaps": [],
            "payouts": []
        }
    ],
    "count": 9,
    "total": 9
}
```

When creating a standing order you may specify a `fixedFee` and a `percentFeeBps` to override your default `Crypto Exchange` fee configuration. The standing order by default uses your crypto exchange fee configuration otherwise.
