---
title: Enrich Account
source_url: https://docs.striga.com/reference/enrich-account
scraped_at: 2025-07-18 17:54:52
---

# Enrich Account

> 🚧
>
> ### Enriching USDC on Solana
>
> To enrich USDC on the Solana network, you must explicitly pass:
>
> `network`: SOL  
> Once specified, the following conditions apply:
>
> `payer` (optional)  
> Specifies who pays for the network fees required to create the Associated Token Account (ATA)
>
> - If not provided, the fee will be deducted from the user’s SOL account.
> - If payer is set to CORPORATE, the fee will be collected from the corporate SOL account
>
> ### Minimum Balance Requirement
>
> The selected payer’s SOL account must have at least 0.01 SOL available to cover the ATA creation fee.
>
> After the USDC\_SOL account is successfully enriched, any unused portion of this amount i.e., the difference between 0.01 SOL and the actual on-chain cost will be refunded to the source account.
>
> ### Async Processing
>
> If the API response returns status: `PENDING_ACCOUNT_ENRICHMENT`, a `PENDING_ACCOUNT_ENRICHMENT` type webhook is also sent to indicate that the enrichment process is underway.
>
> Enrichment will complete asynchronously, and a webhook notification will be sent once the USDC\_SOL account has been fully enriched.

> 📘
>
> ### Note
>
> For multi-chain supported accounts like USDC, it is recommended to use the blockchainDepositAddress found inside each object in the blockchainNetworks array.
>
> This is important because each blockchain may have a different deposit address, especially in cases like Solana, where the address format and requirements differ from EVM-based chains.
>
> In the current implementation, the Enrich API continues to work without the network field as usual.  
> However, `network: SOL` is required only when enriching USDC on Solana.
> This parameter has been introduced to support future multi-chain network additions.
