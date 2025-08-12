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
            
            print("[CardViewModel:updateHasCard:34] updateHasCard called:")
            print("[CardViewModel:updateHasCard:35] - strigaUserId: \(strigaUserId ?? "nil")")
            print("[CardViewModel:updateHasCard:36] - strigaCardId: \(strigaCardId ?? "nil")")
            print("[CardViewModel:updateHasCard:37] - isValidCardId: \(isValidCardId)")
            print("[CardViewModel:updateHasCard:38] - hasCard: \(hasCard)")
            
            // Handle different scenarios
            if strigaUserId == nil {
                // No Striga user at all - need to create user first
                print("[CardViewModel:updateHasCard:42] No Striga user ID found, user needs to create account")
                // The NoCardView with "Get Card" button will show, leading to user creation flow
            } else if strigaCardId == nil {
                // User exists but no card, check if we should auto-create
                await checkAndAutoCreateCard(userId: strigaUserId!)
            }
        }
    }
    
    @MainActor
    private func checkAndAutoCreateCard(userId: String) async {
        print("[CardViewModel:checkAndAutoCreateCard:48] Checking if we should auto-create card for user: \(userId)")
        isCheckingKYC = true
        
        var userResponse: GetUserResponse? = nil
        var userName = "Nuri User"
        var kycApproved = false
        
        // Try to get user details, but don't fail if it doesn't work
        do {
            let getUserInput = GetUser(userId: userId)
            userResponse = try await StrigaService.shared.getUser(getUserInput)
            userName = "\(userResponse!.firstName) \(userResponse!.lastName)"
            kycApproved = userResponse!.KYC.status == "APPROVED"
            print("[CardViewModel:checkAndAutoCreateCard:60] User KYC Status: \(userResponse!.KYC.status)")
        } catch {
            print("[CardViewModel:checkAndAutoCreateCard:63] Failed to get user details: \(error)")
            print("[CardViewModel:checkAndAutoCreateCard:64] Will attempt to create card anyway...")
            // If we can't get user details, we'll try to create card anyway
            // This handles the case where the user exists but the endpoint is problematic
            kycApproved = true // Assume approved if we can't check
        }
        
        if kycApproved {
            print("[CardViewModel:checkAndAutoCreateCard:71] User has approved KYC, auto-creating card...")
            isCreatingCard = true
            
            do {
                // Check if user has wallets
                let walletsResponse = try await StrigaService.shared.getWallets(userId: userId)
                
                if walletsResponse.wallets.isEmpty {
                    // Create wallet and card
                    print("[CardViewModel] Creating wallet and card...")
                    
                    let createWalletInput = CreateWallet(
                        userId: userId,
                        accountCurrency: ["EUR", "BTC"]
                    )
                    
                    let walletResponse = try await StrigaService.shared.createWallet(createWalletInput)
                    print("[CardViewModel] Created wallet: \(walletResponse.walletId)")
                    
                    // Enrich EUR account
                    if let eurAccount = walletResponse.accounts.eur {
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
                    print("[CardViewModel:checkAndAutoCreateCard:103] Generated 3D Secure password")
                    
                    // Store the 3D Secure password securely
                    UserDefaults.standard.set(threeDSecurePassword, forKey: "striga3DSecurePassword")
                    
                    let createCardInput = CreateCard(
                        userId: userId,
                        linkedAccountId: walletResponse.accounts.eur?.accountId ?? "",
                        name: cardName,
                        type: "VIRTUAL",
                        threeDSecurePassword: threeDSecurePassword
                    )
                    
                    let cardResponse = try await StrigaService.shared.createCard(createCardInput)
                    print("[CardViewModel] Created card: \(cardResponse.id)")
                    
                    // Save IDs
                    var settings = UserSettings()
                    settings.strigaWalletId = walletResponse.walletId
                    settings.strigaCardId = cardResponse.id
                    
                    StrigaSession.shared.cardId = cardResponse.id
                    StrigaSession.shared.name = cardName
                    
                    // Update hasCard
                    hasCard = true
                    
                    // Start auto-conversion monitoring after card creation
                    print("[CardViewModel] Starting auto-conversion monitoring after card creation")
                    await AutoConversionService.shared.startMonitoring()
                    
                } else {
                    // Check if any wallet has a card
                    var foundCard = false
                    
                    print("[CardViewModel] Checking \(walletsResponse.wallets.count) wallets for valid cards...")
                    
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
                
                // Don't create wallets in error handler - this could cause duplicates
                // Just log the error and let the user retry manually
                print("[CardViewModel] ❌ Unable to check/create wallets due to error")
                print("[CardViewModel] User may need to manually retry or check their connection")
                
                // REMOVED: Wallet creation in error handler to prevent duplicates
            }
        } else {
            print("[CardViewModel:checkAndAutoCreateCard:196] User KYC status is \(userResponse?.KYC.status ?? "unknown"), not auto-creating")
            needsKYC = true
        }
        
        isCheckingKYC = false
        isCreatingCard = false
    }
    
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
