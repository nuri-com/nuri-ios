# Striga Best Practices Implementation - EUR Enrichment Fix

## The Problem
We were enriching EUR accounts immediately during wallet/card creation, which:
1. **Caused failures** - EUR enrichment was failing during onboarding
2. **Violated best practices** - Striga says to only enrich on-demand
3. **Wasted money** - Enrichment is chargeable
4. **Hit limits** - Max 10 IBANs per user lifetime

## Striga's Official Guidance
From their documentation:
- **"Enrich only when the user actually needs to move money to/from the outside world"**
- **"Don't enrich everything up-front—enrichment is a chargeable action"**
- **"Trigger on intent, not at signup"**
- **"On first 'Add money / Get IBAN' action"**

## The Solution

### 1. CardCreationService.swift
**REMOVED** all EUR enrichment during card creation:
- No EUR enrichment for existing wallets
- No EUR enrichment for new wallets
- Card links to EUR account without enrichment (this is fine)

### 2. WalletListView.swift
**CHANGED** to on-demand enrichment:
- Shows "Tap to get IBAN" for non-enriched EUR accounts
- Blue plus icon indicates action needed
- Enriches EUR account only when user taps
- No automatic background enrichment

### 3. User Experience
**Before:**
- EUR enrichment during onboarding → failures → blocked users
- Automatic enrichment → charges even if never used

**After:**
- Onboarding always succeeds (no EUR enrichment)
- User sees "Tap to get IBAN" option
- Enrichment only when user needs it
- Clear visual indication (blue text/icon)

## Benefits

1. **No More Onboarding Failures**
   - Card creation doesn't depend on EUR enrichment
   - Users can complete signup reliably

2. **Cost Savings**
   - Only charge for enrichment when needed
   - Many users may never need IBAN (card-only usage)

3. **Better Resource Management**
   - Respects 10 IBAN lifetime limit
   - No wasted enrichments

4. **Follows Best Practices**
   - Aligns with Striga's official recommendations
   - Cleaner separation of concerns

## Important Notes

### BTC Enrichment Still Happens
- BTC accounts are still enriched immediately
- This is needed to receive Bitcoin deposits
- BTC enrichment works reliably (blockchain vs banking)

### Card Functionality
- Cards work WITHOUT EUR enrichment
- EUR account just needs to exist and be linked
- IBAN only needed for SEPA transfers IN

### Future Improvements
Consider Striga's suggestion:
- Keep one EUR account for SEPA (enriched on-demand)
- Keep separate EUR account for card spending
- Transfer between them as needed

## Testing Instructions

1. **Uninstall and reinstall the app**
2. **Create new account and complete onboarding**
   - Should complete successfully without EUR enrichment
3. **Check Wallet List**
   - EUR should show "Tap to get IBAN"
   - BTC should show address
4. **Tap EUR row**
   - Should trigger enrichment
   - Should get IBAN if successful
   - Should show retry option if failed

## Summary

This change aligns with Striga's best practices and should eliminate the EUR enrichment failures during onboarding. Users get a better experience, and you save money on unnecessary enrichments.