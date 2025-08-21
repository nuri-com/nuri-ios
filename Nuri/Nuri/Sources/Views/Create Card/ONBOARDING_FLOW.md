# Onboarding Flow - Complete Architecture

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PHONE NUMBER ENTRY                        │
│                  PhoneNumberViewModel                        │
│                   - Collects phone number                    │
│                   - Creates Striga User (NOT wallet)         │
│                   - Triggers SMS from Striga                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    SMS VERIFICATION                          │
│                  EnterSMSCodeView                           │
│                   - User enters 6-digit code                 │
│                   - Verifies with Striga                     │
│                   - Starts KYC process                       │
│                                                              │
│  ⚠️ LAST TIME SMS SCREEN IS SHOWN - NEVER APPEARS AGAIN ⚠️  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      KYC PROCESS                             │
│                    Sumsub SDK                               │
│                   - Identity verification                    │
│                   - Document checks                          │
│                   - On approval → PostKYCCoordinator         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  PostKYCCoordinator                          │
│              Dismisses ALL previous modals                   │
│              Opens NEW modal with UserInfoView               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    USER INFO VIEW                            │
│                    (NEW MODAL)                               │
│                                                              │
│   ┌─────────────────────────────────────────────┐          │
│   │  Shows: Name, Email, Phone, User ID         │          │
│   └─────────────────────────────────────────────┘          │
│                                                              │
│   ┌─────────────────────────────────────────────┐          │
│   │  [Create Wallet & Card] button              │          │
│   │  - Uses CardCreationService                 │          │
│   │  - Ensures ONE wallet, ONE card, ONE IBAN  │          │
│   └─────────────────────────────────────────────┘          │
│                                                              │
│   ┌─────────────────────────────────────────────┐          │
│   │  [Skip for Now] / [Continue to App]         │          │
│   │  - Calls PostKYCCoordinator.dismissToMainApp│          │
│   └─────────────────────────────────────────────┘          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      MAIN APP                                │
│                    CardView                                  │
│                   - NO auto-creation                         │
│                   - Shows existing card or "No Card" view    │
└─────────────────────────────────────────────────────────────┘
```

## Key Rules

### ✅ DO's
- SMS screen is ONLY for verification
- User manually controls wallet/card creation
- ONE wallet, ONE card, ONE IBAN per user
- PostKYCCoordinator manages post-KYC flow
- UserInfoView is presented in NEW modal

### ❌ DON'Ts
- NEVER show SMS screen after KYC
- NEVER auto-create wallets/cards
- NEVER push UserInfoView to navigation stack
- NEVER create duplicate wallets
- NEVER bypass CardCreationService

## File Responsibilities

### PostKYCCoordinator.swift
- Manages transition from KYC to UserInfoView
- Dismisses SMS/KYC flow completely
- Presents UserInfoView in new modal
- Handles dismissal to main app

### EnterSMSCodeViewModel.swift
- Verifies SMS code
- Starts KYC
- On KYC approval → calls PostKYCCoordinator

### UserInfoView.swift
- Shows user information
- Manual wallet/card creation button
- Uses CardCreationService
- Dismisses via PostKYCCoordinator

### CardCreationService.swift
- ONLY service allowed to create wallets/cards
- Enforces ONE wallet, ONE card rule
- Prevents duplicates
- Handles enrichment (IBAN, BTC address)

### CardView.swift
- Shows existing card or "No Card" view
- NO auto-creation (disabled)
- Reads existing wallet/card only