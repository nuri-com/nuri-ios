---
title: Currency Swaps
source_url: https://docs.striga.com/reference/swap-currencies
scraped_at: 2025-07-18 17:50:21
---

# Currency Swaps

Make a swap at market rate from one currency to another. You can fetch the latest market rate using the "rates" endpoint.

The following pairs are enabled implicitly and explicitly for exchange on the Striga platform. The `Ticker` column references the symbol to use when interacting with exchange functions on the platform. Only the tickers listed below can be used for trading.

| Pair | Ticker |
| --- | --- |
| USDC/EUR | USDCEUR |
| BTC/USDC | BTCUSDC |
| BTC/EUR | BTCEUR |
| ETH/EUR | ETHEUR |
| POL/EUR | POLEUR |
| BNB/EUR | BNBEUR |
| SOL/EUR | SOLEUR |

Please note that the amount sent in any transaction is denominated in the lowest divisible unit of the currency being sent (Eg: cents, satoshis or wei).

> 📘
>
> ### Minimum Trade Values
>
> Please note that all orders will not go through unless they meet the minimum order size provided by our liquidity partners, which is usually on the order of 10 EUR equivalent.
>
> ~~Minimum trade values are applied on the value of the order, i.e. the amount of currency that is received as the result of a swap.
>
> ~~Minimum **order sizes** typically are on the range of 10-20 EUR equivalent, following the typical minimums larger [exchanges such as Kraken use](https://support.kraken.com/hc/en-us/articles/205893708-Minimum-order-size-volume-for-trading). Trade minimums are not strictly checked on production and follow the trade minimums very close to the Kraken trade minimums.
>
> The minimum order size goes by base currency. The base currency is the left currency in each pair. For example, BTC is the base currency in the pair BTC/EUR.

## Fixed rate guarantees

---

A common use case is where your application displays a crypto to fiat exchange rate that does not change for a fixed period of time (for example: 90 seconds) allowing the user to decide on their course of action with a fixed price.

With Striga, our [rates API](https://docs.striga.com/reference/exchange-rates) continually refreshes rates from our liquidity providers such that we execute market orders when we receive a request to swap currencies.

To build a flow where you can control the exchange rate, the "Swap Currencies" API (/swap) now takes in a `proposedRate` parameter which will forcefully execute a trade on our ledger at the rate that you want to execute a trade at, **irrespective of what the the then prevailing market rate is**.

There are natural limitations in how far apart your proposed rate can be in comparison with market rates (default +- 3%) such that potential losses are capped and billed to your company in the standard billing cycle. Please talk to your account manager at Striga to discuss pricing and enablement for this feature.

---

## Market orders

The API returns a property `order` which contains `id`, `credit`, `debit` and `price` with sub fields respectively. The `order.id` field is only present when there is a multi-currency transaction, i.e. a swap from one currency to another. In this case, the `direction` and `ticker` values are also present. The `amountFloat` value under `credit` and `debit` depict the value in whole currencies (EUR, BTC etc.). The `amount` value depicts the value in the smallest divisible unit.

An example response is shown below -

JSON

```
{
    "id": "1c721c03-e34a-4073-a7ec-eab99e017f7d",
    "sourceAccountId": "0148ae0856b1457ff3b59f2ac965b58e",
    "destinationAccountId": "ec7d87e7109dcc0ab6d04650762fb72f",
    "memo": "implement web-enabled synergies",
    "status": "COMMITTED",
    "txType": "CURRENCY_EXCHANGE",
    "order": {
        "id": "e165a7e2-3dee-46bc-9025-5e5c8c389eea",
        "price": "24104.93",
        "type": "buy",
        "ticker": "BTCEUR",
        "debit": {
            "currency": "EUR",
            "amountFloat": "7264.32",
            "amount": "726432"
        },
        "credit": {
            "currency": "BTC",
            "amountFloat": "0.30136241",
            "amount": "30136241"
        }
    },
    "datetime": "2023-08-23T11:35:06.057Z",
    "balanceBefore": {
        "balance": "726432",
        "currency": "cents"
    },
    "balanceAfter": {
        "balance": "0",
        "currency": "cents"
    },
    "sourceSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
    "destinationSyncedOwnerId": "b2ccf978-2da7-4ac9-9db7-5398c4c6b212",
    "feeEstimate": {
        "totalFee": "7389",
        "networkFee": "0",
        "ourFee": "0",
        "theirFee": "7389",
        "feeCurrency": "EUR",
        "fixedFeeDetails": {
            "amount": "50",
            "exchangeRate": "1"
        },
        "percentageFeeDetails": {
            "amount": "7339"
        }
    }
}
```

## Ticker interpretation

### JSON TradeMap -

The following trademap can be used on your application to cleanly calculate prices on buying/selling crypto currencies according to Striga's ticker structure.

JSON

```
toCurrency: {
    BTC: {
      fromCurrency: {
        EUR: {
          direction: 'buy',
          ticker: 'BTCEUR,
        },
        USDT: {
          direction: 'buy',
          ticker: 'BTCUSDT,
        },
        USDC: {
          direction: 'buy',
          ticker: 'BTCUSDC,
        },
      },
    },
    EUR: {
      fromCurrency: {
        USDT: {
          direction: 'sell',
          ticker: 'USDTEUR,
        },
        USDC: {
          direction: 'sell',
          ticker: 'USDCEUR,
        },
        BTC: {
          direction: 'sell',
          ticker: 'BTCEUR,
        },
        ETH: {
          direction: 'sell',
          ticker: 'ETHEUR,
        },
        BNB: {
          direction: 'sell',
          ticker: 'BNBEUR',
        },
        MATIC_POLYGON: {
          direction: 'sell',
          ticker: 'MATICEUR',
        },
      },
    },
    USDT: {
      fromCurrency: {
        EUR: {
          direction: 'buy',
          ticker: 'USDTEUR,
        },
        USDC: {
          direction: 'sell',
          ticker: 'USDCUSDT,
        },
        BTC: {
          direction: 'sell',
          ticker: 'BTCUSDT,
        },
      },
    },
    USDC: {
      fromCurrency: {
        USDT: {
          direction: 'buy',
          ticker: 'USDCUSDT,
        },
        EUR: {
          direction: 'buy',
          ticker: 'USDCEUR,
        },
        BTC: {
          direction: 'sell',
          ticker: 'BTCUSDC,
        },
      },
    },
    ETH: {
      fromCurrency: {
        EUR: {
          direction: 'buy',
          ticker: 'ETHEUR,
        },
      },
    },
    BNB: {
      fromCurrency: {
        EUR: {
          direction: 'buy',
          ticker: 'BNBEUR',
        },
      },
    },
    MATIC_POLYGON: {
      fromCurrency: {
        EUR: {
          direction: 'buy',
          ticker: 'MATICEUR',
        },
      },
    },
```

> ❗️
>
> ### Buy USDT Trade Restriction after Sat Dec 28 2024 00:00:00 GMT+0000
>
> The decision to stop executing USDT buy orders has been made in line with our compliance program regarding the Markets in Crypto-Assets Regulation (MiCAR) which enters into force 30 December 2024. At the time of this announcement, the USDT token has not received regulatory approval to be offered in the EU/EEA, which is why we have taken this step to restrict our service offering for USDT.
>
> Please note that all other operations involving USDT will remain unaffected by this change. You and your customers will still be able to deposit USDT, withdraw USDT, and place USDT sell orders (orders to convert USDT into other crypto-assets or EUR) post 27 December 2024. Spending USDT with cards is also unaffected.
>
> The Swap API will return an error code 41001 with the message "Restricted direction" after Sat Dec 28 2024 00:00:00 GMT+0000 **(Unix Timestamp - 1735344000000)** for swap API requests where the destination account currency is USDT.
>
> On the sandbox environment, the trading pairs USDC/USDT, BTC/USDT, and USDT/EUR have been removed. Existing users with a USDT account will no longer be able to swap using these pairs.
