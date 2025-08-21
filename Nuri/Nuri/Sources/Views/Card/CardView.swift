import SwiftUI
import Combine
import UIKit
import StrigaAPI

class CreateCardNavigation: ObservableObject {
     @Published var isPresented: Bool = false
}

class CardViewModel: ObservableObject {

    private let userSettings = ObservableUserSettings()
    private var tokens: Set<AnyCancellable> = []

    @Published var hasCard: Bool = false
    @Published var isCheckingKYC: Bool = false
    @Published var isCreatingCard: Bool = false
    @Published var needsKYC: Bool = false

    init() {
        userSettings.strigaUserId
            .sink { [weak self] userId in
                self?.updateHasCard()
            }
            .store(in: &tokens)
    }

    private func updateHasCard() {
        Task { @MainActor in
            let strigaUserId = UserSettings().strigaUserId
            let strigaCardId = UserSettings().strigaCardId
            
            // Validate that cardId is not just non-nil, but also not "UNLINKED" or empty
            let isValidCardId = strigaCardId != nil && 
                               strigaCardId != "UNLINKED" && 
                               !strigaCardId!.isEmpty
            
            hasCard = strigaUserId != nil && isValidCardId
            
            print("\n" + String(repeating: "=", count: 60))
            print("💳 [CardViewModel] CARD STATUS CHECK")
            print("   👤 Striga User ID: \(strigaUserId as String? ?? "NONE")")
            print("   💳 Striga Card ID: \(strigaCardId as String? ?? "NONE")")
            print("   ✅ Valid Card: \(isValidCardId)")
            print("   📱 Has Card: \(hasCard)")
            print(String(repeating: "=", count: 60))
            
            // Handle different scenarios
            if strigaUserId == nil {
                // No Striga user at all - need to create user first
                print("[CardViewModel:updateHasCard:42] No Striga user ID found, user needs to create account")
                // The NoCardView with "Get Card" button will show, leading to user creation flow
            } else if strigaCardId == nil {
                // User exists but no card, first try to sync to recover existing card
                print("\n🔄 [CardViewModel] USER EXISTS BUT NO CARD STORED LOCALLY")
                print("📱 Scenario: This is likely a fresh install or app recovery")
                print("🔍 Action: Attempting to recover card from Striga API...")
                
                let syncSuccess = await StrigaSyncService.shared.syncUserData(userId: strigaUserId!)
                
                // Check if sync recovered the card
                let recoveredCardId = UserSettings().strigaCardId
                if let cardId = recoveredCardId, !cardId.isEmpty && cardId != "UNLINKED" {
                    print("\n✅ [CardViewModel] CARD RECOVERY SUCCESSFUL!")
                    print("   💳 Recovered Card ID: \(cardId)")
                    print("   📱 User can now access their existing card")
                    hasCard = true
                    StrigaSession.shared.cardId = cardId
                } else {
                    print("\n⚠️ [CardViewModel] NO EXISTING CARD FOUND")
                    print("   📝 This user has never created a card")
                    print("   ⛔ AUTO-CREATION DISABLED - User must manually create from UserInfoView")
                    // DISABLED: Automatic wallet/card creation
                    // Users must manually create wallet/card from UserInfoView after KYC
                    // await checkAndAutoCreateCard(userId: strigaUserId!)
                }
            }
        }
    }
    
    // DISABLED: Automatic wallet/card creation
    // This function is kept for reference but should NOT be called
    // Users must manually create wallet/card from UserInfoView after KYC
    /*
    @MainActor
    private func checkAndAutoCreateCard(userId: String) async {
        print("\n" + String(repeating: "=", count: 80))
        print("🎯 [CardViewModel] AUTO-CREATE/RECOVERY CHECK")
        print("   👤 User ID: \(userId)")
        print("   📝 Purpose: Determine if user needs a new card or can proceed")
        print(String(repeating: "=", count: 80))
        
        isCheckingKYC = true
        
        var userName = "Nuri User"
        
        // Skip the broken /users/get endpoint and go straight to checking wallets
        // If the user has wallets, they must have passed KYC already
        print("\n⚠️ [CardViewModel] NOTE: /users/get endpoint is broken (404)")
        print("🔄 Strategy: Check wallets directly - if user has wallets, KYC must be approved")
        
        // For existing users with wallets, we can assume KYC is approved
        // New users without wallets will get an error when trying to get wallets
        let kycApproved = true // We'll verify this by checking if wallets exist
        
        if kycApproved {
            print("\n📊 [CardViewModel] Proceeding to check wallet status...")
            isCreatingCard = true
            
            do {
                // Check if user has wallets
                let walletsResponse = try await StrigaService.shared.getWallets(userId: userId)
                
                print("\n🔍 [CardViewModel] CARD CREATION SAFETY CHECK")
                print("   Found \(walletsResponse.wallets.count) wallet(s)")
                
                // CRITICAL: Check ALL wallets for ANY existing cards before creating
                var existingCardFound = false
                var existingCardId: String? = nil
                
                for wallet in walletsResponse.wallets {
                    let allAccounts = [
                        wallet.accounts.eur,
                        wallet.accounts.btc, 
                        wallet.accounts.eth,
                        wallet.accounts.usdc,
                        wallet.accounts.usdt,
                        wallet.accounts.sol,
                        wallet.accounts.bnb,
                        wallet.accounts.pol
                    ].compactMap { $0 }
                    
                    for account in allAccounts {
                        if let linkedCardId = account.linkedCardId,
                           linkedCardId != "UNLINKED" && !linkedCardId.isEmpty {
                            existingCardFound = true
                            existingCardId = linkedCardId
                            print("   ⚠️ FOUND EXISTING CARD: \(linkedCardId)")
                            print("   📍 In wallet: \(wallet.walletId)")
                            print("   💱 Account: \(account.currency)")
                            break
                        }
                    }
                    if existingCardFound { break }
                }
                
                if existingCardFound {
                    print("\n❌ [CardViewModel] CARD CREATION BLOCKED - Card already exists!")
                    print("   💳 Existing Card ID: \(existingCardId as String? ?? "unknown")")
                    print("   ✅ Recovering existing card instead...")
                    
                    // Store the found card
                    if let cardId = existingCardId {
                        var settings = UserSettings()
                        settings.strigaCardId = cardId
                        StrigaSession.shared.cardId = cardId
                        hasCard = true
                    }
                    
                    isCheckingKYC = false
                    isCreatingCard = false
                    return  // EXIT - DO NOT CREATE NEW CARD
                }
                
                if walletsResponse.wallets.isEmpty {
                    // Use CardCreationService to create wallet and card
                    print("\n✅ [CardViewModel] No wallets exist - using CardCreationService")
                    print("   📝 CardCreationService will handle wallet/card creation properly...")
                    
                    let cardService = CardCreationServiceProvider.shared.service
                    let cardResult = try await cardService.createCard(name: userName, userId: userId)
                    
                    print("[CardViewModel] Card created via CardCreationService: \(cardResult.id)")
                    
                    // Save IDs
                    var settings = UserSettings()
                    settings.strigaWalletId = cardResult.parentWalletId
                    settings.strigaCardId = cardResult.id
                    
                    StrigaSession.shared.cardId = cardResult.id
                    StrigaSession.shared.name = userName
                    
                    // Update hasCard
                    hasCard = true
                    
                    // Start auto-conversion monitoring after card creation
                    print("[CardViewModel] Starting auto-conversion monitoring after card creation")
                    await AutoConversionService.shared.startMonitoring()
                    
                } else {
                    // Wallets exist - be VERY careful about creating cards
                    print("\n⚠️ [CardViewModel] WALLETS EXIST - Double-checking for cards...")
                    print("   🔍 Checking \(walletsResponse.wallets.count) wallet(s) thoroughly...")
                    
                    var foundCard = false
                    
                    for (index, wallet) in walletsResponse.wallets.enumerated() {
                        print("[CardViewModel] Wallet \(index + 1) (ID: \(wallet.walletId)):")
                        
                        // Check each account for valid card IDs
                        var validCardId: String? = nil
                        
                        if let eurCardId = wallet.accounts.eur?.linkedCardId,
                           eurCardId != "UNLINKED" && !eurCardId.isEmpty {
                            validCardId = eurCardId
                            print("  - EUR account has valid card: \(eurCardId)")
                        }
                        
                        if let btcCardId = wallet.accounts.btc?.linkedCardId,
                           btcCardId != "UNLINKED" && !btcCardId.isEmpty {
                            validCardId = btcCardId
                            print("  - BTC account has valid card: \(btcCardId)")
                        }
                        
                        if let ethCardId = wallet.accounts.eth?.linkedCardId,
                           ethCardId != "UNLINKED" && !ethCardId.isEmpty {
                            validCardId = ethCardId
                            print("  - ETH account has valid card: \(ethCardId)")
                        }
                        
                        if let usdcCardId = wallet.accounts.usdc?.linkedCardId,
                           usdcCardId != "UNLINKED" && !usdcCardId.isEmpty {
                            validCardId = usdcCardId
                            print("  - USDC account has valid card: \(usdcCardId)")
                        }
                        
                        if let usdtCardId = wallet.accounts.usdt?.linkedCardId,
                           usdtCardId != "UNLINKED" && !usdtCardId.isEmpty {
                            validCardId = usdtCardId
                            print("  - USDT account has valid card: \(usdtCardId)")
                        }
                        
                        // If we found a valid card in this wallet, save it
                        if let cardId = validCardId {
                            print("[CardViewModel] ✅ Found valid card \(cardId) in wallet \(wallet.walletId)")
                            
                            // Save the found card ID and wallet ID
                            var settings = UserSettings()
                            settings.strigaCardId = cardId
                            settings.strigaWalletId = wallet.walletId
                            
                            StrigaSession.shared.cardId = cardId
                            hasCard = true
                            foundCard = true
                            break
                        } else {
                            print("  - No valid cards in this wallet (all are UNLINKED or empty)")
                        }
                    }
                    
                    if !foundCard {
                        // FINAL SAFETY CHECK before creating card
                        print("\n🚨 [CardViewModel] FINAL CARD CREATION CHECK")
                        print("   📊 Wallets exist: YES (\(walletsResponse.wallets.count))")
                        print("   💳 Cards found: NO")
                        print("   ✅ Safe to create ONE card")
                        
                        // User has wallets but no cards, create a card
                        if let firstWallet = walletsResponse.wallets.first,
                           let eurAccount = firstWallet.accounts.eur {
                            
                            // Enrich if needed
                            if !eurAccount.enriched {
                                let enrichInput = EnrichAccount(
                                    accountId: eurAccount.accountId,
                                    userId: userId
                                )
                                
                                _ = try await StrigaService.shared.enrichAccount(enrichInput)
                                print("[CardViewModel] Enriched EUR account")
                            }
                            
                            // Create card with 3D Secure password
                            let cardName = userName
                            // Generate secure password following Striga's policy (same as user creation flow)
                            let threeDSecurePassword = generateSecurePassword()
                            print("[CardViewModel:checkAndAutoCreateCard:185] Generated 3D Secure password")
                            
                            // Store the 3D Secure password securely
                            UserDefaults.standard.set(threeDSecurePassword, forKey: "striga3DSecurePassword")
                            
                            let createCardInput = CreateCard(
                                userId: userId,
                                linkedAccountId: eurAccount.accountId,
                                name: cardName,
                                type: "VIRTUAL",
                                threeDSecurePassword: threeDSecurePassword
                            )
                            
                            let cardResponse = try await StrigaService.shared.createCard(createCardInput)
                            print("[CardViewModel] Created card: \(cardResponse.id)")
                            
                            // Save IDs
                            var settings = UserSettings()
                            settings.strigaWalletId = firstWallet.walletId
                            settings.strigaCardId = cardResponse.id
                            
                            StrigaSession.shared.cardId = cardResponse.id
                            StrigaSession.shared.name = cardName
                            
                            hasCard = true
                            
                            // Start auto-conversion monitoring after card creation
                            print("[CardViewModel] Starting auto-conversion monitoring after card creation")
                            await AutoConversionService.shared.startMonitoring()
                        }
                    }
                }
            } catch {
                print("[CardViewModel:checkAndAutoCreateCard:193] Error checking wallets: \(error)")
                
                // Check if this is a KYC error
                if let errorResponse = error as? ErrorResponse {
                    if errorResponse.errorCode == "30007" && errorResponse.message == "UNAPPROVED_IDENTITY" {
                        print("[CardViewModel] ❌ KYC is not approved (status: \(errorResponse.errorDetails ?? "unknown"))")
                        print("[CardViewModel] User needs to complete KYC approval before cards can be created")
                        needsKYC = true
                    } else {
                        print("[CardViewModel] ❌ API Error: \(errorResponse.message) (code: \(errorResponse.errorCode))")
                    }
                } else {
                    print("[CardViewModel] ❌ Unable to check/create wallets due to error")
                    print("[CardViewModel] User may need to manually retry or check their connection")
                }
                
                // REMOVED: Wallet creation in error handler to prevent duplicates
            }
        }
        
        isCheckingKYC = false
        isCreatingCard = false
    }
    */
    
    // Copy the exact password generation logic from CardCreationService
    private func generateSecurePassword() -> String {
        // Use safer subset of allowed characters to avoid HMAC encoding issues
        // Avoiding: " \ / which can cause JSON/HMAC encoding problems
        let uppercase = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
        let numbers = Array("0123456789")
        let special = Array("!#;:?&*()+=,.[]{}")
        
        // Use 16 characters for a strong password
        var password = ""
        
        // Ensure at least 2 of each type for strength
        password.append(contentsOf: [uppercase.randomElement()!, uppercase.randomElement()!])
        password.append(contentsOf: [lowercase.randomElement()!, lowercase.randomElement()!])
        password.append(contentsOf: [numbers.randomElement()!, numbers.randomElement()!])
        password.append(contentsOf: [special.randomElement()!, special.randomElement()!])
        
        // Fill remaining 8 characters
        let allCharacters = uppercase + lowercase + numbers + special
        for _ in 0..<8 {
            password.append(allCharacters.randomElement()!)
        }
        
        // Shuffle the password
        return String(password.shuffled())
    }
}

struct CardView: View {

    @ObservedObject var viewModel = CardViewModel()

    @StateObject private var navigation = CreateCardNavigation()

    var body: some View {
        Group {
            if viewModel.hasCard {
                CardViewActive()
            } else if viewModel.isCheckingKYC || viewModel.isCreatingCard {
                // Show loading state while checking KYC or creating card
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text(viewModel.isCreatingCard ? "Creating your card..." : "Checking account status...")
                        .font(.headline)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                    
                    Text("This may take a few moments")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
            } else {
                NoCardView()
            }
        }
        .sheet(isPresented: $navigation.isPresented) {
            CreateCardView()
        }
        .environmentObject(navigation)
    }
}

#if DEBUG
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView()
    }
}
#endif
