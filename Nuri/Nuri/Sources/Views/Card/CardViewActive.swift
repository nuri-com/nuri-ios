import SwiftUI
import UIKit
import StrigaAPI

struct CardViewActive: View {
    @State private var isTransactionsPresented = false
    @State private var showCardDetails = false
    @State private var isLargeQRPresented = false
    @State private var isCardFrozen = false
    @State private var isTopUpPresented = false
    @State private var isShareSheetPresented = false
    @State private var qrImage: UIImage? = nil
    @State private var walletBalance = "0.00"
    @State private var cardHolderName = "Loading..."
    @State private var cardNumber = ""
    @State private var cardExpiry = ""
    @State private var cardCVV = ""
    @State private var cardAuthToken: String?
    @State private var showCardDetailsFlow = false
    @State private var btcAddress = "Loading..." // Will be populated from API
    @State private var linkedWalletId: String?
    @State private var maskedCardNumber = "**** **** **** ****"
    @State private var isRefreshing = false
    @State private var refreshTimer: Timer?
    @State private var iban = ""
    @State private var bic = ""
    @State private var accountHolderName = ""
    
    private let striga = StrigaService.shared
    
    init() {
        // Ensure Striga is configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
            print("[CardViewActive] Configured with Striga credentials")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Unified header
            NuriHeader<AnyView, AnyView>(title: "") {
                AnyView(
                    Image("HeaderLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                )
            } trailing: {
                AnyView(
                    Button(action: {
                        isTopUpPresented = true
                    }) {
                        Text("+ Add Money")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                )
            }

            VStack {
                Spacer()
                
                // EUR amount at top with IBAN and Bitcoin address below
                VStack(spacing: 12) {
                    // Amount - same design as before
                    HStack {
                        Text("€ \(walletBalance)")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.black)
                        
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.leading, 8)
                        }
                    }
                    
                    // IBAN with bank icon as subtitle
                    if !iban.isEmpty {
                        HStack(spacing: 8) {
                            Image("vector-icon-card")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.black.opacity(0.6))
                                .frame(width: 40, height: 40)
                            
                            Text(iban)
                                .font(.custom("Inter", size: 16))
                                .foregroundColor(.black.opacity(0.6))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button(action: {
                                // Copy IBAN + Name + BIC
                                let copyText = """
                                IBAN: \(iban)
                                Name: \(accountHolderName)
                                BIC: \(bic)
                                """
                                UIPasteboard.general.string = copyText
                                print("📋 IBAN details copied:\n\(copyText)")
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.black.opacity(0.6))
                                    .font(.system(size: 20))
                            }
                        }
                    }
                    
                    // Bitcoin address with bitcoin icon
                    HStack(spacing: 8) {
                        Image("bitcoin-icon")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.black.opacity(0.6))
                            .frame(width: 40, height: 40)
                        
                        Text(btcAddress)
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(.black.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = btcAddress
                            print("📋 Bitcoin address copied: \(btcAddress)")
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.black.opacity(0.6))
                                .font(.system(size: 20))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 15)

                let cardOpacity = isCardFrozen ? 0.4 : 1.0

                // Always show the Striga card preview with masked details
                StrigaCardPreview(
                    holder: cardHolderName,
                    maskedNumber: maskedCardNumber,
                    expiry: cardExpiry
                )
                .opacity(cardOpacity)
                .transition(.opacity)
                .padding(.bottom, 20)

                HStack(spacing: 32) {
                    SmallIconButton(icon: "eye", 
                                  title: "Show") {
                        print("\n════════════════════════════════════════")
                        print("🎯 [CardViewActive] STARTING STREAMLINED CARD FLOW")
                        print("════════════════════════════════════════")
                        print("📍 Simplified Flow:")
                        print("  1️⃣  Auto-start consent request in background")
                        print("  2️⃣  OTP screen appears automatically")
                        print("  3️⃣  Auto-submit when 6 digits entered")
                        print("  4️⃣  Card details display immediately")
                        print("════════════════════════════════════════\n")
                        
                        // Verify we have required IDs
                        let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId ?? ""
                        let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId ?? ""
                        
                        print("📱 [CardViewActive] User ID: \(userId.isEmpty ? "MISSING ❌" : userId)")
                        print("📱 [CardViewActive] Card ID: \(cardId.isEmpty ? "MISSING ❌" : cardId)")
                        
                        if userId.isEmpty || cardId.isEmpty {
                            print("❌ [CardViewActive] ERROR: Missing required IDs")
                            return
                        }
                        
                        print("✅ [CardViewActive] Opening streamlined flow...")
                        showCardDetailsFlow = true
                    }
                    SmallIconButton(icon: isCardFrozen ? "lock" : "lock_open", title: isCardFrozen ? "Unfreeze" : "Freeze") {
                        toggleCardFreeze()
                    }
                    SmallIconButton(icon: "money_topup", title: "Top-Up") {
                        isTopUpPresented = true
                    }
                }
                .padding(.bottom, 30)

                Button(action: {

                }) {
                    HStack(spacing: 8) {
                        Image("apple-wallet")
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text("Add to Apple Wallet")
                            .font(.brandBody)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color("PrimaryNuriBlack"))
                    .cornerRadius(100)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)

            // Place the transactions button at the bottom, outside the main content stack
            Button(action: {
                isTransactionsPresented = true
            }) {
                Image("link-icon-to-transactions")
                    .resizable()
                    .frame(width: 24, height: 13)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(NuriAsset.background.swiftUIColor)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $isTransactionsPresented) {
            UnifiedTransactionsView()
        }
        .sheet(isPresented: $isTopUpPresented) {
            NavigationStack {
                WalletListView()
            }
        }
        .onAppear {
            loadCardData()
            fetchCardAndWalletDetails()
            startAutoRefresh()
            
            // Also fetch immediately after 2 seconds to catch any pending transactions
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("🚀 [CardViewActive] Quick refresh to check for BTC...")
                fetchCardAndWalletDetails(showRefreshIndicator: false)
            }
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .refreshable {
            // Pull-to-refresh support
            await Task {
                fetchCardAndWalletDetails(showRefreshIndicator: true)
            }.value
        }
        .fullScreenCover(isPresented: $showCardDetailsFlow) {
            CardDetailsFlowView(
                userId: StrigaSession.shared.userId ?? UserSettings().strigaUserId ?? "",
                cardId: StrigaSession.shared.cardId ?? UserSettings().strigaCardId ?? ""
            )
        }
        .fullScreenCover(isPresented: $isLargeQRPresented) {
            GeometryReader { geo in
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        QRCodeImage(text: btcAddress)
                            .frame(width: min(geo.size.width, geo.size.height) * 0.8,
                                   height: min(geo.size.width, geo.size.height) * 0.8)
                            .onAppear {
                                UIPasteboard.general.string = btcAddress
                                let renderer = ImageRenderer(content:
                                    QRCodeImage(text: btcAddress)
                                        .frame(width: 300, height: 300)
                                )
                                if let uiImage = renderer.uiImage {
                                    qrImage = uiImage
                                }
                            }
                            .onTapGesture { isLargeQRPresented = false }
                    }
                    Text("Bitcoin address copied to clipboard")
                        .font(.headline)
                        .padding()
                    Button(action: {
                        isShareSheetPresented = true
                    }) {
                        NuriButton(icon: "share", title: "Share Address", style: .primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.white.opacity(0.95).ignoresSafeArea())
                .sheet(isPresented: $isShareSheetPresented) {
                    if let qrImage = qrImage {
                        ShareSheet(activityItems: [qrImage, btcAddress])
                    } else {
                        ShareSheet(activityItems: [btcAddress])
                    }
                }
            }
        }
    }
    
    private func loadCardData() {
        // Load basic card info (non-sensitive)
        if let name = StrigaSession.shared.name {
            cardHolderName = name
        }
        
        // Store IDs in session for later use
        if let userId = UserSettings().strigaUserId {
            StrigaSession.shared.userId = userId
            print("[CardView] Loaded userId: \(userId)")
        }
        if let cardId = UserSettings().strigaCardId {
            StrigaSession.shared.cardId = cardId
            print("[CardView] Loaded cardId: \(cardId)")
            
            // Check if we have a mock card ID and need to create a real card
            if cardId == "mock-card-id" {
                print("[CardView] WARNING: Found mock card ID, clearing it to trigger real card creation")
                UserSettings().strigaCardId = nil
                StrigaSession.shared.cardId = nil
                // This will trigger the NoCardView which can create a real card
            }
        } else {
            print("[CardView] WARNING: No card ID found in UserSettings")
        }
        
        // Don't set default balance here - let fetchCardAndWalletDetails handle it
        // Card frozen state will be set from API response
    }
    
    private func fetchCardAndWalletDetails(showRefreshIndicator: Bool = false) {
        Task {
            if showRefreshIndicator {
                await MainActor.run {
                    isRefreshing = true
                }
            }
            
            do {
                // Get user and card IDs
                guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                      let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                    print("❌ [CardViewActive] Missing user or card ID")
                    await MainActor.run {
                        isRefreshing = false
                    }
                    return
                }
                
                print("🔄 [CardViewActive] Fetching card and wallet details...")
                
                // Fetch card details to get masked number and expiry
                let cardResponse = try await striga.getCard(.init(
                    userId: userId,
                    cardId: cardId,
                    authToken: nil
                ))
                
                await MainActor.run {
                    // Update card display with fetched data
                    self.cardHolderName = cardResponse.name
                    self.maskedCardNumber = formatMaskedCardNumber(cardResponse.maskedCardNumber)
                    self.cardExpiry = String(format: "%02d/%02d", cardResponse.expiryMonth, cardResponse.expiryYear % 100)
                    
                    // Update card frozen state based on API response
                    self.isCardFrozen = (cardResponse.status != "ACTIVE")
                    print("📊 [CardViewActive] Card status: \(cardResponse.status), frozen: \(self.isCardFrozen)")
                    
                    // Store the linked wallet ID
                    self.linkedWalletId = cardResponse.parentWalletId
                }
                
                // Fetch wallet details to get Bitcoin address and balance
                if !cardResponse.parentWalletId.isEmpty {
                    print("💳 [CardViewActive] Fetching wallet details for Card's Wallet ID: \(cardResponse.parentWalletId)")
                    
                    // Try to get all wallets using the correct endpoint
                    do {
                        print("🔍 [CardViewActive] Fetching user's wallets...")
                        let walletsResponse = try await striga.getWallets(userId: userId)
                        print("📊 [CardViewActive] Found \(walletsResponse.wallets.count) wallet(s)")
                        
                        // Find the wallet that matches the card's parent wallet ID
                        guard let walletResponse = walletsResponse.wallets.first(where: { $0.walletId == cardResponse.parentWalletId }) else {
                            print("❌ [CardViewActive] Card's parent wallet not found in user's wallets")
                            // Try to get the specific wallet details as fallback
                            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
                            await processWalletResponseFromCreateWallet(walletResponse, userId: userId)
                            return
                        }
                        
                        print("✅ [CardViewActive] Found matching wallet: \(walletResponse.walletId)")
                        print("    - Created: \(walletResponse.createdAt)")
                        print("    - Balance: \(walletResponse.walletBalance)")
                        print("    - EUR account: \(walletResponse.accounts.eur?.accountId ?? "none")")
                        print("    - BTC account: \(walletResponse.accounts.btc?.accountId ?? "none")")
                        
                        // Process the wallet response
                        await processWalletResponse(walletResponse, userId: userId)
                    } catch {
                        print("⚠️ [CardViewActive] Could not fetch wallets: \(error)")
                        // Fallback: try to get specific wallet
                        do {
                            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
                            await processWalletResponseFromCreateWallet(walletResponse, userId: userId)
                        } catch {
                            print("❌ [CardViewActive] Failed to fetch wallet details: \(error)")
                        }
                    }
                }
            } catch {
                print("❌ [CardViewActive] Error loading card data: \(error)")
                await MainActor.run {
                    isRefreshing = false
                }
            }
        }
    }
    
    private func processWalletResponse(_ walletResponse: GetWalletsResponse.Wallet, userId: String) async {
        await MainActor.run {
            // Update wallet balance from EUR account
            if let eurAccount = walletResponse.accounts.eur {
                // Log all balance fields for debugging
                print("💰 [CardViewActive] EUR Account Balance Details:")
                print("  - amount (smallest unit): \(eurAccount.availableBalance.amount)")
                print("  - hAmount (human readable): \(eurAccount.availableBalance.hAmount)")
                print("  - currency: \(eurAccount.availableBalance.currency)")
                
                // Use hAmount if available (human-readable format)
                if !eurAccount.availableBalance.hAmount.isEmpty {
                    // Remove any currency symbol if present in hAmount
                    let cleanAmount = eurAccount.availableBalance.hAmount
                        .replacingOccurrences(of: "€", with: "")
                        .replacingOccurrences(of: "EUR", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    self.walletBalance = cleanAmount
                    print("✅ [CardViewActive] Using hAmount for balance: \(self.walletBalance)")
                } else {
                    // Fallback to parsing amount (in smallest unit - cents for EUR)
                    let amount = eurAccount.availableBalance.amount
                    if let cents = Double(amount) {
                        let euros = cents / 100.0
                        self.walletBalance = String(format: "%.2f", euros)
                        print("✅ [CardViewActive] Converted cents to euros: \(self.walletBalance)")
                    }
                }
                
                // Extract IBAN details if available
                if let bankingDetails = eurAccount.bankingDetails {
                    self.iban = bankingDetails.iban
                    self.bic = bankingDetails.bic
                    self.accountHolderName = bankingDetails.accountHolderName
                    print("🏦 [CardViewActive] IBAN details loaded:")
                    print("  - IBAN: \(self.iban)")
                    print("  - BIC: \(self.bic)")
                    print("  - Name: \(self.accountHolderName)")
                }
            } else {
                print("⚠️ [CardViewActive] No EUR account found in wallet")
                self.walletBalance = "0.00"
            }
            
            // Get Bitcoin account from the wallet
            print("🔍 [CardViewActive] Getting blockchain addresses from wallet response...")
            
            // Check BTC account
            if let btcAccount = walletResponse.accounts.btc {
                print("💰 [CardViewActive] Bitcoin account found:")
                print("  - Account ID: \(btcAccount.accountId)")
                print("  - Enriched: \(btcAccount.enriched)")
                print("  - BTC Balance: \(btcAccount.availableBalance.amount) \(btcAccount.availableBalance.currency)")
                
                // Check if address is already in the response
                if let btcAddress = btcAccount.blockchainDepositAddress {
                    self.btcAddress = btcAddress
                    print("✅ [CardViewActive] Bitcoin address from wallet: \(btcAddress)")
                } else if btcAccount.enriched {
                    // Account says it's enriched but no address, try enriching again
                    Task {
                        do {
                            print("🔄 [CardViewActive] Re-enriching BTC account ID: \(btcAccount.accountId)")
                            let enrichResponse = try await self.striga.enrichAccount(
                                EnrichAccount(accountId: btcAccount.accountId, userId: userId)
                            )
                            print("✅ [CardViewActive] BTC account enriched successfully")
                            
                            await MainActor.run {
                                if let btcAddress = enrichResponse.blockchainDepositAddress {
                                    self.btcAddress = btcAddress
                                    print("✅ [CardViewActive] Bitcoin address found: \(btcAddress)")
                                } else if let networks = enrichResponse.blockchainNetworks, !networks.isEmpty {
                                    self.btcAddress = networks[0].blockchainDepositAddress
                                    print("✅ [CardViewActive] Bitcoin address from network: \(self.btcAddress)")
                                } else {
                                    print("⚠️ [CardViewActive] No BTC address in enrich response")
                                    // Keep the default address instead of showing account ID
                                }
                            }
                        } catch {
                            print("❌ [CardViewActive] Error enriching BTC: \(error)")
                            // Keep the default address instead of showing account ID
                        }
                    }
                } else {
                    // Not enriched, need to enrich
                    Task {
                        do {
                            print("🔄 [CardViewActive] Enriching BTC account ID: \(btcAccount.accountId)")
                            let enrichResponse = try await self.striga.enrichAccount(
                                EnrichAccount(accountId: btcAccount.accountId, userId: userId)
                            )
                            print("✅ [CardViewActive] BTC account enriched successfully")
                            
                            await MainActor.run {
                                if let btcAddress = enrichResponse.blockchainDepositAddress {
                                    self.btcAddress = btcAddress
                                    print("✅ [CardViewActive] Bitcoin address found: \(btcAddress)")
                                } else if let networks = enrichResponse.blockchainNetworks, !networks.isEmpty {
                                    self.btcAddress = networks[0].blockchainDepositAddress
                                    print("✅ [CardViewActive] Bitcoin address from network: \(self.btcAddress)")
                                } else {
                                    print("⚠️ [CardViewActive] No BTC address in enrich response")
                                    // Keep the default address instead of showing account ID
                                }
                            }
                        } catch {
                            print("❌ [CardViewActive] Error enriching BTC: \(error)")
                            // Keep the default address instead of showing account ID
                        }
                    }
                }
            }
            
            // Check ETH account (optional - for debugging)
            if let ethAccount = walletResponse.accounts.eth {
                if let ethAddress = ethAccount.blockchainDepositAddress {
                    print("💰 [CardViewActive] ETH address from wallet: \(ethAddress)")
                }
            }
            
            // Check BTC balance and auto-convert if needed
            if let btcAccount = walletResponse.accounts.btc {
                let btcAmount = btcAccount.availableBalance.amount
                if btcAmount != "0" && !btcAmount.isEmpty {
                    print("💱 [CardViewActive] Found \(btcAmount) sats - initiating auto-conversion to EUR")
                    self.autoConvertBTCtoEUR(
                        btcAmount: btcAmount,
                        btcAccountId: btcAccount.accountId,
                        eurAccountId: walletResponse.accounts.eur?.accountId ?? ""
                    )
                }
            } else {
                // No BTC account
                print("⚠️ [CardViewActive] No Bitcoin account found in wallet")
                self.btcAddress = "No BTC wallet"
            }
        }
    }
    
    // Handle CreateWalletResponse type from getWallet endpoint
    private func processWalletResponseFromCreateWallet(_ walletResponse: CreateWalletResponse, userId: String) async {
        await MainActor.run {
            // Update wallet balance from EUR account
            if let eurAccount = walletResponse.accounts.eur {
                // Use hAmount if available (human-readable format)
                if !eurAccount.availableBalance.hAmount.isEmpty {
                    let cleanAmount = eurAccount.availableBalance.hAmount
                        .replacingOccurrences(of: "€", with: "")
                        .replacingOccurrences(of: "EUR", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    self.walletBalance = cleanAmount
                } else {
                    // Fallback to parsing amount
                    let amount = eurAccount.availableBalance.amount
                    if let cents = Double(amount) {
                        let euros = cents / 100.0
                        self.walletBalance = String(format: "%.2f", euros)
                    }
                }
                
                // Extract IBAN details if available
                if let bankingDetails = eurAccount.bankingDetails {
                    self.iban = bankingDetails.iban
                    self.bic = bankingDetails.bic
                    self.accountHolderName = bankingDetails.accountHolderName
                }
            } else {
                self.walletBalance = "0.00"
            }
            
            // Get Bitcoin address from BTC account
            if let btcAccount = walletResponse.accounts.btc {
                if let btcAddress = btcAccount.blockchainDepositAddress {
                    self.btcAddress = btcAddress
                } else if btcAccount.enriched {
                    // Re-enrich if needed
                    Task {
                        do {
                            let enrichResponse = try await self.striga.enrichAccount(
                                EnrichAccount(accountId: btcAccount.accountId, userId: userId)
                            )
                            await MainActor.run {
                                if let btcAddress = enrichResponse.blockchainDepositAddress {
                                    self.btcAddress = btcAddress
                                } else if let networks = enrichResponse.blockchainNetworks, !networks.isEmpty {
                                    self.btcAddress = networks[0].blockchainDepositAddress
                                }
                            }
                        } catch {
                            print("❌ [CardViewActive] Error enriching BTC: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func formatMaskedCardNumber(_ masked: String) -> String {
        // Convert 474367******7720 to 4743 67** **** 7720
        let clean = masked.replacingOccurrences(of: " ", with: "")
        var formatted = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted += String(char)
        }
        return formatted
    }
    
    private func startAutoRefresh() {
        // Stop any existing timer
        stopAutoRefresh()
        
        // Start new timer - refresh every 5 seconds for faster BTC detection
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task {
                await MainActor.run {
                    print("🔄 [CardViewActive] Auto-refreshing balance...")
                }
                fetchCardAndWalletDetails(showRefreshIndicator: false)
            }
        }
        print("⏰ [CardViewActive] Auto-refresh timer started (5 seconds)")
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("⏰ [CardViewActive] Auto-refresh timer stopped")
    }
    
    private func toggleCardFreeze() {
        Task {
            do {
                guard let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                    print("❌ [CardViewActive] No card ID found")
                    return
                }
                
                print("🔄 [CardViewActive] Toggling card freeze state...")
                
                if isCardFrozen {
                    // Unblock the card
                    print("🔓 [CardViewActive] Unblocking card...")
                    _ = try await striga.blockCard(UnblockCard(cardId: cardId))
                    
                    await MainActor.run {
                        isCardFrozen = false
                        print("✅ [CardViewActive] Card unblocked successfully")
                    }
                } else {
                    // Block the card
                    print("🔒 [CardViewActive] Blocking card...")
                    _ = try await striga.blockCard(BlockCard(
                        cardId: cardId,
                        blockType: "FRAUD" // Options: FRAUD, LOST, STOLEN, ATM_RETENTION, OTHER
                    ))
                    
                    await MainActor.run {
                        isCardFrozen = true
                        print("✅ [CardViewActive] Card blocked successfully")
                    }
                }
                
                // Refresh card details to get updated status
                fetchCardAndWalletDetails(showRefreshIndicator: false)
                
            } catch {
                print("❌ [CardViewActive] Error toggling card freeze: \(error)")
                // Revert the state on error
                await MainActor.run {
                    isCardFrozen.toggle()
                }
            }
        }
    }
    
    private func autoConvertBTCtoEUR(btcAmount: String, btcAccountId: String, eurAccountId: String) {
        Task {
            do {
                print("💱 [CardViewActive] Starting BTC to EUR conversion...")
                print("  - BTC Amount (sats): \(btcAmount)")
                print("  - BTC Account ID: \(btcAccountId)")
                print("  - EUR Account ID: \(eurAccountId)")
                
                guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId else {
                    print("❌ [CardViewActive] Missing user ID for conversion")
                    return
                }
                
                guard !eurAccountId.isEmpty else {
                    print("❌ [CardViewActive] No EUR account available for conversion")
                    return
                }
                
                // Execute the swap from BTC to EUR
                print("🔄 [CardViewActive] Executing swap from BTC to EUR...")
                let swapResponse = try await striga.swapCurrencies(.init(
                    userId: userId,
                    sourceAccountId: btcAccountId,
                    destinationAccountId: eurAccountId,
                    amount: btcAmount  // Amount in smallest unit (satoshis)
                ))
                
                print("✅ [CardViewActive] BTC to EUR conversion successful!")
                print("  - Transaction ID: \(swapResponse.id)")
                print("  - Status: \(swapResponse.status)")
                print("  - Source Amount: \(swapResponse.sourceAmount) sats")
                print("  - Destination Amount: \(swapResponse.destinationAmount) EUR cents")
                print("  - Exchange Rate: \(swapResponse.exchangeRate)")
                if let fee = swapResponse.fee {
                    print("  - Fee: \(fee)")
                }
                
                // Refresh balance after conversion
                await MainActor.run {
                    print("🔄 [CardViewActive] Refreshing balance after conversion...")
                    self.fetchCardAndWalletDetails(showRefreshIndicator: true)
                }
                
            } catch {
                print("❌ [CardViewActive] Error in BTC to EUR conversion: \(error)")
                // Log the specific error details
                if let urlError = error as? URLError {
                    print("  - URL Error: \(urlError.localizedDescription)")
                } else {
                    print("  - Error details: \(String(describing: error))")
                }
            }
        }
    }
    
    // ⚠️ DEPRECATED - THIS DOESN'T WORK! ⚠️
    // request-consent is NOT a REST API endpoint!
    // It's a JavaScript SDK method that ONLY works in WebView
    @MainActor
    private func requestCardConsentInBackground_DEPRECATED() async {
        print("[CardView] ⛔ FATAL ERROR: Attempting to call non-existent REST endpoint")
        print("[CardView] ❌ /api/v1/card/request-consent does NOT exist as REST API")
        print("[CardView] ℹ️ request-consent is ONLY available as JavaScript SDK method:")
        print("[CardView]    StrigaUXPlugin.requestConsent({ userId })")
        print("[CardView] ✅ SOLUTION: Use HostedCardView which handles this in WebView")
        print("[CardView] 📖 See STRIGA_CARD_FLOW_DOCUMENTATION.md for details")
    }
    
    // This function is deprecated - use HostedCardView instead
    // The request-consent endpoint doesn't exist as a REST API
    // It's a JavaScript SDK method that must be called from a WebView
    
    @MainActor
    private func loadCardDetailsWithoutAuth() async {
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                print("[CardView] Missing user or card ID")
                return
            }
            
            print("[CardView] Fetching card details WITHOUT auth token")
            print("[CardView] User ID: \(userId)")
            print("[CardView] Card ID: \(cardId)")
            
            // Fetch card details without auth token - will get masked card number
            let cardDetails = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            print("[CardView] Card details received (masked)")
            
            // Update UI with card data
            cardHolderName = cardDetails.name
            cardNumber = cardDetails.maskedCardNumber // This will be like ****1234
            cardExpiry = String(format: "%02d/%02d", cardDetails.expiryMonth, cardDetails.expiryYear % 100)
            cardCVV = "***" // CVV is always masked without auth
            
            // Show the card
            showCardDetails = true
            
            print("[CardView] Card details displayed (masked version)")
            
        } catch {
            print("[CardView] Error loading card details: \(error)")
            if let validationError = error as? ValidationErrorResponse {
                print("[CardView] Validation error: \(validationError.message)")
                // Handle specific errors if needed
            }
        }
    }
    
    @MainActor
    private func loadRealCardData(authToken: String) async {
        do {
            guard let userId = StrigaSession.shared.userId,
                  let cardId = StrigaSession.shared.cardId else {
                print("[CardView] Missing user or card ID")
                return
            }
            
            print("[CardView] Fetching card details with auth token")
            print("[CardView] Card ID: \(cardId)")
            
            // Always try to fetch real card details with auth token
            let cardDetails = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: authToken
            ))
            
            print("[CardView] Card details received")
            
            // Update UI with real card data
            cardHolderName = cardDetails.name
            
            // Format card number with spaces
            if let fullCardNumber = cardDetails.cardNumber {
                // Add spaces every 4 digits
                let cleaned = fullCardNumber.replacingOccurrences(of: " ", with: "")
                var formatted = ""
                for (index, char) in cleaned.enumerated() {
                    if index > 0 && index % 4 == 0 {
                        formatted += " "
                    }
                    formatted += String(char)
                }
                cardNumber = formatted
            } else {
                // Fallback to masked number
                cardNumber = cardDetails.maskedCardNumber
            }
            
            // Format expiry date
            cardExpiry = String(format: "%02d/%02d", cardDetails.expiryMonth, cardDetails.expiryYear % 100)
            
            // Set CVV
            cardCVV = cardDetails.cvv ?? "***"
            
            print("[CardView] Card details updated successfully")
            
        } catch {
            print("[CardView] Error loading card details: \(error)")
            if let validationError = error as? ValidationErrorResponse {
                print("[CardView] Validation error: \(validationError.message)")
            }
        }
    }
}

// MARK: - Card detail components

private enum CardTextStyle {
    case label, value, name
    var font: Font {
        switch self {
        case .label: return .custom("Inter", size: 16)
        case .value: return .custom("Inter", size: 16).weight(.semibold)
        case .name:  return .custom("Inter", size: 16).weight(.semibold)
        }
    }
}

private extension Text {
    func cardStyle(_ style: CardTextStyle) -> some View {
        self.font(style.font).foregroundColor(.white)
    }
}

private struct ValueWithCopy: View {
    let text: String
    let style: CardTextStyle
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .cardStyle(style)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
            Button(action: { UIPasteboard.general.string = text }) {
                Image("copy-icon")
                    .resizable()
                    .frame(width: 14, height: 14)
            }
        }
    }
}

private struct CardModel {
    let holder: String
    let number: String
    let expiry: String
    let cvv: String
}

// Striga card preview - gradient background like a real card
private struct StrigaCardPreview: View {
    let holder: String
    let maskedNumber: String
    let expiry: String
    
    var body: some View {
        // Standard credit card aspect ratio: width/height = 1.586 (85.6mm x 53.98mm)
        ZStack {
            // Card background - gradient like premium cards
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.20),
                    Color(red: 0.25, green: 0.25, blue: 0.30)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 0) {
                // Card Holder section at top
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARD HOLDER")
                        .font(.custom("Inter", size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.5)
                    Text(holder.uppercased())
                        .font(.custom("Inter", size: 18).weight(.medium))
                        .foregroundColor(.white)
                }
                .padding(.top, 24)
                .padding(.leading, 21)
                .padding(.trailing, 40)
                
                // Card Number section in middle
                VStack(alignment: .leading, spacing: 4) {
                    Text("CARD NUMBER")
                        .font(.custom("Inter", size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.5)
                    Text(maskedNumber)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(1.5)
                }
                .padding(.top, 24)
                .padding(.leading, 21)
                .padding(.trailing, 40)
                
                Spacer()
                
                // Bottom row - Expires and CVV
                HStack(spacing: 50) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPIRES")
                            .font(.custom("Inter", size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(0.5)
                        Text(expiry)
                            .font(.custom("Inter", size: 18).weight(.medium))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV")
                            .font(.custom("Inter", size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(0.5)
                        Text("***")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 21)
                .padding(.trailing, 40)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

private struct CardMini: View {
    let card: CardModel
    let qrAddress: String
    let onQRTap: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(card.holder).cardStyle(.name)

                Text("Card number").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                ValueWithCopy(text: card.number, style: .value)

                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expiry").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                        ValueWithCopy(text: card.expiry, style: .value)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                        ValueWithCopy(text: card.cvv, style: .value)
                    }
                }
            }
            Spacer(minLength: 12)
            QRCodeImage(text: qrAddress)
                .frame(width: 48, height: 48)
                .onTapGesture { onQRTap() }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color("PrimaryNuriBlack"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .aspectRatio(257/163, contentMode: .fit)
        .frame(minHeight: 196)
    }
}

private struct SmallIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriBlack"))
            }
        }
    }
}

#if DEBUG
#Preview {
    CardViewActive()
}
#endif

// ShareSheet helper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// NOTE: Card OTP verification is handled through HostedCardView for iOS
// The request-consent is a JavaScript SDK method, not a REST API
