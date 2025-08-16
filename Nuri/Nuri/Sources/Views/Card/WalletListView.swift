import SwiftUI
import StrigaAPI

struct WalletListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wallets: [WalletItem] = []
    @State private var isLoading = true
    @State private var eurAccountId = ""
    @State private var autoConversionTimer: Timer?
    @State private var failedSwapAttempts: [String: Int] = [:] // Track failed attempts per account
    @State private var lastSwapAttempt: [String: Date] = [:] // Track last attempt time per account
    @State private var autoConversionEnabled = true // Enabled by default, user-controllable
    
    private let striga = StrigaService.shared
    private let maxRetryAttempts = 3
    private let retryDelayMinutes = 30.0 // Wait 30 minutes after max failures
    
    struct WalletItem {
        let currency: String
        let iconName: String
        let address: String
        let accountId: String
        let isIBAN: Bool
        
        var displayAddress: String {
            if isIBAN {
                return address // IBAN format
            } else {
                return address // Blockchain address
            }
        }
        
        var copyText: String {
            return address
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - same design as TransactionsView
                NuriHeader<AnyView, AnyView>.logo(title: "Top-Up Wallets", onClose: { dismiss() })
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if isLoading {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Loading wallets...")
                                    .font(.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                            }
                            .padding(.top, 40)
                        } else if wallets.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "wallet.pass")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                                Text("No wallets available")
                                    .font(.custom("Inter", size: 18).weight(.medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            }
                            .padding(.top, 40)
                        } else {
                            // Auto-conversion status banner
                            if !eurAccountId.isEmpty {
                                VStack(spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Auto-conversion to EUR")
                                                .font(.custom("Inter", size: 14).weight(.medium))
                                                .foregroundColor(Color("PrimaryNuriBlack"))
                                            Text(autoConversionEnabled ? "Active - checking every 60 seconds" : "Disabled")
                                                .font(.custom("Inter", size: 12))
                                                .foregroundColor(Color(hex: "#6D6D86"))
                                        }
                                        Spacer()
                                        Toggle("", isOn: $autoConversionEnabled)
                                            .labelsHidden()
                                            .onChange(of: autoConversionEnabled) { _, newValue in
                                                if newValue {
                                                    startMonitoringForAutoConversion()
                                                    print("✅ [WalletListView] Auto-conversion enabled")
                                                } else {
                                                    autoConversionTimer?.invalidate()
                                                    autoConversionTimer = nil
                                                    // Reset failure counters when disabled
                                                    failedSwapAttempts.removeAll()
                                                    lastSwapAttempt.removeAll()
                                                    print("🔴 [WalletListView] Auto-conversion disabled")
                                                }
                                            }
                                    }
                                    
                                    // Manual trigger button for testing
                                    Button(action: {
                                        print("🔄 [WalletListView] Manual swap trigger activated")
                                        Task {
                                            await checkAndConvertBalances()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text("Check & Convert Now")
                                        }
                                        .font(.custom("Inter", size: 13).weight(.medium))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color("PrimaryNuriPurple"))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                            }
                            
                            // Wallet list
                            ForEach(Array(wallets.enumerated()), id: \.offset) { index, wallet in
                                WalletRow(wallet: wallet) {
                                    // Copy address when tapped
                                    UIPasteboard.general.string = wallet.copyText
                                    print("📋 Copied \(wallet.currency) address: \(wallet.copyText)")
                                }
                                
                                if index != wallets.count - 1 {
                                    Color.clear.frame(height: 8)             // Top gutter (8 pt)
                                    Color(hex: "#E0E0E0").frame(height: 1)  // Divider (1 pt)
                                    Color.clear.frame(height: 8)             // Bottom gutter (8 pt)
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .task {
            await loadWallets()
        }
    }
    
    private func loadWallets() async {
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                print("❌ [WalletListView] Missing user or card ID")
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            print("🔄 [WalletListView] Loading wallets...")
            
            // Get card to find the linked wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            // Get wallet details
            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
            
            var loadedWallets: [WalletItem] = []
            
            // 1. IBAN (EUR account)
            if let eurAccount = walletResponse.accounts.eur,
               let bankingDetails = eurAccount.bankingDetails {
                
                await MainActor.run {
                    self.eurAccountId = eurAccount.accountId
                }
                
                loadedWallets.append(WalletItem(
                    currency: "EUR / IBAN",
                    iconName: "vector-icon-card",
                    address: bankingDetails.iban,
                    accountId: eurAccount.accountId,
                    isIBAN: true
                ))
            }
            
            // 2. Bitcoin
            if let btcAccount = walletResponse.accounts.btc {
                let btcAddress = await enrichAndGetAddress(account: btcAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "Bitcoin",
                    iconName: "bitcoin-icon",
                    address: btcAddress.isEmpty ? "Loading..." : btcAddress,
                    accountId: btcAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 3. USDC (ERC20 and possibly other networks)
            if let usdcAccount = walletResponse.accounts.usdc {
                // For multi-network support, we need to enrich first
                let enrichedAddresses = await enrichAndGetMultipleAddresses(account: usdcAccount, userId: userId)
                if !enrichedAddresses.isEmpty {
                    for (network, address) in enrichedAddresses {
                        // Default to ERC20 if no specific network specified
                        let networkLabel = network.isEmpty ? "ERC20" : network
                        loadedWallets.append(WalletItem(
                            currency: "USDC (\(networkLabel))",
                            iconName: "usdc-icon",
                            address: address,
                            accountId: usdcAccount.accountId,
                            isIBAN: false
                        ))
                    }
                } else {
                    // Show even if not enriched yet
                    loadedWallets.append(WalletItem(
                        currency: "USDC (ERC20)",
                        iconName: "usdc-icon",
                        address: "Loading...",
                        accountId: usdcAccount.accountId,
                        isIBAN: false
                    ))
                }
            }
            
            // 4. ETH
            if let ethAccount = walletResponse.accounts.eth {
                let ethAddress = await enrichAndGetAddress(account: ethAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "Ethereum",
                    iconName: "eth-icon",
                    address: ethAddress.isEmpty ? "Loading..." : ethAddress,
                    accountId: ethAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 5. BNB (BSC)
            if let bnbAccount = walletResponse.accounts.bnb {
                let bnbAddress = await enrichAndGetAddress(account: bnbAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "BNB (BSC)",
                    iconName: "bnb-icon",
                    address: bnbAddress.isEmpty ? "Loading..." : bnbAddress,
                    accountId: bnbAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 6. POL (Polygon/ERC20)
            if let polAccount = walletResponse.accounts.pol {
                let polAddresses = await enrichAndGetMultipleAddresses(account: polAccount, userId: userId)
                if !polAddresses.isEmpty {
                    for (network, address) in polAddresses {
                        // POL can be on Ethereum (ERC20) or Polygon network
                        let networkLabel = network.isEmpty ? "Polygon" : network
                        loadedWallets.append(WalletItem(
                            currency: "POL (\(networkLabel))",
                            iconName: "pol-icon",
                            address: address,
                            accountId: polAccount.accountId,
                            isIBAN: false
                        ))
                    }
                } else {
                    loadedWallets.append(WalletItem(
                        currency: "POL (Polygon)",
                        iconName: "pol-icon",
                        address: "Loading...",
                        accountId: polAccount.accountId,
                        isIBAN: false
                    ))
                }
            }
            
            // 7. SOL (Solana)
            if let solAccount = walletResponse.accounts.sol {
                let solAddress = await enrichAndGetAddress(account: solAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "SOL",
                    iconName: "sol-icon",
                    address: solAddress.isEmpty ? "Loading..." : solAddress,
                    accountId: solAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 8. USDT (ERC20)
            if let usdtAccount = walletResponse.accounts.usdt {
                let usdtAddress = await enrichAndGetAddress(account: usdtAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "USDT (ERC20)",
                    iconName: "usdt-icon",
                    address: usdtAddress.isEmpty ? "Loading..." : usdtAddress,
                    accountId: usdtAccount.accountId,
                    isIBAN: false
                ))
            }
            
            await MainActor.run {
                self.wallets = loadedWallets
                self.isLoading = false
            }
            
            print("✅ [WalletListView] Loaded \(loadedWallets.count) wallets")
            
            // Start monitoring for auto-conversion if enabled (default is true)
            if autoConversionEnabled {
                startMonitoringForAutoConversion()
            }
            
        } catch {
            print("❌ [WalletListView] Error loading wallets: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func enrichAndGetAddress(account: CreateWalletResponse.Account, userId: String) async -> String {
        // Check if address already exists
        if let address = account.blockchainDepositAddress, !address.isEmpty {
            return address
        }
        
        // Need to enrich the account
        do {
            print("🔄 [WalletListView] Enriching \(account.currency) account: \(account.accountId)")
            let enrichResponse = try await striga.enrichAccount(
                EnrichAccount(accountId: account.accountId, userId: userId)
            )
            
            if let address = enrichResponse.blockchainDepositAddress {
                print("✅ [WalletListView] Got \(account.currency) address: \(address)")
                return address
            } else if let networks = enrichResponse.blockchainNetworks, !networks.isEmpty {
                if let address = networks[0].blockchainDepositAddress {
                    print("✅ [WalletListView] Got \(account.currency) address from network: \(address)")
                    return address
                }
            }
        } catch {
            print("❌ [WalletListView] Error enriching \(account.currency): \(error)")
        }
        
        return ""
    }
    
    private func enrichAndGetMultipleAddresses(account: CreateWalletResponse.Account, userId: String) async -> [(network: String, address: String)] {
        var addresses: [(network: String, address: String)] = []
        
        // Check if address already exists
        if let address = account.blockchainDepositAddress, !address.isEmpty {
            addresses.append(("", address))
            return addresses
        }
        
        // Need to enrich the account
        do {
            print("🔄 [WalletListView] Enriching \(account.currency) account for multiple networks: \(account.accountId)")
            let enrichResponse = try await striga.enrichAccount(
                EnrichAccount(accountId: account.accountId, userId: userId)
            )
            
            // Check for multiple networks
            if let networks = enrichResponse.blockchainNetworks, !networks.isEmpty {
                for network in networks {
                    if let networkName = network.networkName ?? network.network ?? network.name,
                       let address = network.blockchainDepositAddress {
                        addresses.append((networkName, address))
                        print("✅ [WalletListView] Got \(account.currency) address for \(networkName): \(address)")
                    }
                }
            } else if let address = enrichResponse.blockchainDepositAddress {
                // Single address
                addresses.append(("", address))
                print("✅ [WalletListView] Got \(account.currency) address: \(address)")
            }
        } catch {
            print("❌ [WalletListView] Error enriching \(account.currency): \(error)")
        }
        
        return addresses
    }
    
    private func startMonitoringForAutoConversion() {
        // Only start if enabled
        guard autoConversionEnabled else {
            print("⚠️ [WalletListView] Auto-conversion is disabled")
            return
        }
        
        // Cancel any existing timer
        autoConversionTimer?.invalidate()
        
        // Start a timer to check balances and auto-convert
        // Check every 60 seconds instead of 10 to avoid too frequent attempts
        autoConversionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                await checkAndConvertBalances()
            }
        }
        
        // Also check immediately when enabled
        Task {
            await checkAndConvertBalances()
        }
    }
    
    private func checkAndConvertBalances() async {
        guard !eurAccountId.isEmpty else { return }
        guard autoConversionEnabled else {
            print("🔴 [WalletListView] Auto-conversion is disabled, skipping balance check")
            return
        }
        
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                return
            }
            
            // Get card's wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            // Get fresh wallet details
            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
            
            // Minimum EUR value required for swap (€10 as per Striga requirements)
            // This seems to be the actual minimum that Striga accepts
            let minimumEURValue = 10.0
            
            print("💱 [WalletListView] Checking balances for auto-conversion (minimum: €\(minimumEURValue))")
            
            // Check each crypto account for balances
            let accounts = [
                ("BTC", walletResponse.accounts.btc),
                ("USDC", walletResponse.accounts.usdc),
                ("ETH", walletResponse.accounts.eth),
                ("SOL", walletResponse.accounts.sol),
                ("BNB", walletResponse.accounts.bnb),
                ("POL", walletResponse.accounts.pol),
                ("USDT", walletResponse.accounts.usdt)
            ]
            
            for (currency, account) in accounts {
                guard let account = account else { continue }
                
                // Log account details for debugging
                print("🔍 [WalletListView] Checking \(currency) account:")
                print("  - Account ID: \(account.accountId)")
                print("  - Available Balance: \(account.availableBalance.amount) \(account.availableBalance.currency)")
                print("  - Status: \(account.status)")
                if let blockchainAddress = account.blockchainDepositAddress {
                    print("  - Blockchain Address: \(blockchainAddress.prefix(10))...")
                }
                
                let balance = account.availableBalance.amount
                if balance != "0" && !balance.isEmpty {
                    // Check if this account has too many failed attempts
                    let failedAttempts = failedSwapAttempts[account.accountId] ?? 0
                    if failedAttempts >= maxRetryAttempts {
                        // Check if enough time has passed to retry
                        if let lastAttempt = lastSwapAttempt[account.accountId] {
                            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt) / 60.0 // in minutes
                            if timeSinceLastAttempt < retryDelayMinutes {
                                print("⏸️ [WalletListView] \(currency) swap paused due to \(failedAttempts) failures. Waiting \(Int(retryDelayMinutes - timeSinceLastAttempt)) more minutes")
                                continue
                            } else {
                                // Reset counters after waiting period
                                print("🔄 [WalletListView] Resetting failure counter for \(currency) after waiting period")
                                failedSwapAttempts[account.accountId] = 0
                            }
                        }
                    }
                    
                    // First, get the exchange rate to check if balance meets €10 minimum
                    let balanceDouble = Double(balance) ?? 0
                    if balanceDouble <= 0 {
                        continue
                    }
                    
                    // Convert balance to proper format for exchange rate check
                    let formattedAmount: String
                    if currency == "BTC" {
                        // Convert satoshis to BTC
                        let btcAmount = balanceDouble / 100_000_000
                        formattedAmount = String(format: "%.8f", btcAmount)
                    } else if currency == "ETH" || currency == "BNB" || currency == "POL" {
                        // Convert wei to ETH/BNB/POL
                        let ethAmount = balanceDouble / 1_000_000_000_000_000_000
                        formattedAmount = String(format: "%.18f", ethAmount)
                    } else if currency == "SOL" {
                        // Convert lamports to SOL
                        let solAmount = balanceDouble / 1_000_000_000
                        formattedAmount = String(format: "%.9f", solAmount)
                    } else if currency == "USDC" || currency == "USDT" {
                        // Convert cents to dollars
                        let usdAmount = balanceDouble / 100
                        formattedAmount = String(format: "%.2f", usdAmount)
                    } else {
                        formattedAmount = balance
                    }
                    
                    // Try to get exchange rate to check EUR value
                    do {
                        print("📊 [WalletListView] Checking exchange rate for \(formattedAmount) \(currency)")
                        let rateResponse = try await striga.getExchangeRate(
                            from: currency,
                            to: "EUR",
                            amount: formattedAmount
                        )
                        
                        let eurValue = Double(rateResponse.amount) ?? 0
                        print("💶 [WalletListView] \(currency) balance worth €\(String(format: "%.2f", eurValue))")
                        
                        // Check if EUR value meets minimum requirement
                        if eurValue < minimumEURValue {
                            print("⚠️ [WalletListView] \(currency) value €\(String(format: "%.2f", eurValue)) below minimum €\(minimumEURValue), skipping swap")
                            continue
                        }
                    } catch {
                        print("⚠️ [WalletListView] Could not get exchange rate for \(currency), using fallback minimum check")
                        // Fallback to conservative minimums if rate check fails
                        let fallbackMinimums: [String: Double] = [
                            "BTC": 20000,      // 20k sats ≈ €18
                            "ETH": 5_000_000_000_000_000, // 0.005 ETH ≈ €15
                            "USDC": 1000,      // 10 USDC ≈ €9.2
                            "USDT": 1000,      // 10 USDT ≈ €9.2
                            "BNB": 20_000_000_000_000_000, // 0.02 BNB ≈ €12
                            "POL": 10_000_000_000_000_000_000, // 10 POL ≈ €10
                            "SOL": 50_000_000  // 0.05 SOL ≈ €10
                        ]
                        
                        if let minAmount = fallbackMinimums[currency], balanceDouble < minAmount {
                            print("⚠️ [WalletListView] \(currency) balance \(balance) below fallback minimum \(minAmount), skipping swap")
                            continue
                        }
                    }
                    
                    print("💱 [WalletListView] Found \(balance) \(currency) - converting to EUR (attempt \(failedAttempts + 1)/\(maxRetryAttempts))")
                    print("  - Account ID: \(account.accountId)")
                    print("  - EUR Account ID: \(eurAccountId)")
                    
                    // Execute swap to EUR
                    do {
                        print("🔄 [WalletListView] ===== ATTEMPTING SWAP =====")
                        print("📊 Swap Request Parameters:")
                        print("  - userId: \(userId)")
                        print("  - sourceAccountId: \(account.accountId)")
                        print("  - destinationAccountId: \(eurAccountId)")
                        print("  - amount: \(balance)")
                        print("  - currency: \(currency)")
                        print("  - Account status: \(account.status)")
                        print("  - Available balance: \(account.availableBalance.amount) \(account.availableBalance.currency)")
                        
                        // Log the actual amount in human-readable format
                        if currency == "ETH" {
                            let ethAmount = (Double(balance) ?? 0) / 1_000_000_000_000_000_000
                            print("  - Amount (ETH): \(String(format: "%.18f", ethAmount))")
                        } else if currency == "BTC" {
                            let btcAmount = (Double(balance) ?? 0) / 100_000_000
                            print("  - Amount (BTC): \(String(format: "%.8f", btcAmount))")
                        }
                        
                        let swapResponse = try await striga.swapCurrencies(.init(
                            userId: userId,
                            sourceAccountId: account.accountId,
                            destinationAccountId: eurAccountId,
                            amount: balance
                        ))
                        
                        print("✅ [WalletListView] ===== SWAP SUCCESSFUL =====")
                        print("👍 Transaction ID: \(swapResponse.id)")
                        print("👍 Status: \(swapResponse.status)")
                        print("👍 Source: \(swapResponse.sourceAmount) \(currency)")
                        print("👍 Destination: \(swapResponse.destinationAmount) EUR")
                        print("👍 Exchange Rate: \(swapResponse.exchangeRate)")
                        print("====================================")
                        
                        // Reset failure counter on success
                        failedSwapAttempts[account.accountId] = 0
                        lastSwapAttempt.removeValue(forKey: account.accountId)
                        
                    } catch {
                        print("❌ [WalletListView] ===== SWAP FAILED =====")
                        print("🔴 Error Type: \(type(of: error))")
                        print("🔴 Error Description: \(error)")
                        print("📝 Context:")
                        print("  - Currency: \(currency)")
                        print("  - Balance attempted: \(balance) (smallest unit)")
                        print("  - Source account: \(account.accountId)")
                        print("  - Destination account: \(eurAccountId)")
                        
                        // Log more details about the error
                        if let validationError = error as? StrigaAPI.ValidationErrorResponse {
                            print("🚨 [WalletListView] Validation Error:")
                            print("  - Message: \(validationError.message)")
                            print("  - Error Code: \(validationError.errorCode)")
                            print("  - Field Errors:")
                            for field in validationError.errorDetails {
                                print("    - \(field.param): \(field.msg)")
                                
                                // Check if it's an amount-related error
                                if field.param == "amount" && 
                                   (field.msg.lowercased().contains("minimum") || 
                                    field.msg.lowercased().contains("insufficient") ||
                                    field.msg.lowercased().contains("below")) {
                                    print("🛑 [WalletListView] Swap failed due to minimum amount requirements: \(field.msg)")
                                    // Don't retry if it's a minimum amount issue
                                    failedSwapAttempts[account.accountId] = maxRetryAttempts
                                }
                            }
                        } else if let strigaError = error as? StrigaAPI.ErrorResponse {
                            print("🚨 [WalletListView] ===== STRIGA API ERROR =====")
                            print("📍 Error Message: \(strigaError.message)")
                            print("📍 Error Code: \(strigaError.errorCode)")
                            print("📍 Error Details: \(strigaError.errorDetails)")
                            print("=================================")
                            
                            // Check for specific error codes that indicate permanent failures
                            if strigaError.errorCode.contains("INSUFFICIENT") || 
                               strigaError.errorCode.contains("MINIMUM") ||
                               strigaError.message.lowercased().contains("minimum") ||
                               strigaError.message.lowercased().contains("insufficient") ||
                               strigaError.message.lowercased().contains("below") ||
                               strigaError.errorDetails.lowercased().contains("minimum") {
                                print("🛑 [WalletListView] Swap failed due to minimum amount requirements")
                                // Don't retry if it's a minimum amount issue
                                failedSwapAttempts[account.accountId] = maxRetryAttempts
                            }
                        } else if let urlError = error as? URLError {
                            print("  - URL Error: \(urlError.localizedDescription)")
                        } else if let decodingError = error as? DecodingError {
                            print("  - Decoding Error: \(decodingError)")
                        } else {
                            print("🔴 [WalletListView] Unknown Error Type")
                            print("  - Error type: \(type(of: error))")
                            print("  - Error details: \(String(describing: error))")
                            print("  - Error localized: \(error.localizedDescription)")
                            
                            // Try to extract any additional info from NSError
                            let nsError = error as NSError
                            print("  - NSError domain: \(nsError.domain)")
                            print("  - NSError code: \(nsError.code)")
                            print("  - NSError userInfo: \(nsError.userInfo)")
                        }
                        print("====================================")
                        
                        // Increment failure counter
                        let currentFailures = failedSwapAttempts[account.accountId] ?? 0
                        failedSwapAttempts[account.accountId] = currentFailures + 1
                        lastSwapAttempt[account.accountId] = Date()
                        
                        print("⚠️ [WalletListView] Failed swap attempt \(currentFailures + 1)/\(maxRetryAttempts) for \(currency)")
                        
                        // Stop timer if we've hit too many total failures
                        let totalFailures = failedSwapAttempts.values.reduce(0, +)
                        if totalFailures >= accounts.count * maxRetryAttempts {
                            print("🛑 [WalletListView] Stopping auto-conversion timer due to excessive failures")
                            await MainActor.run {
                                autoConversionTimer?.invalidate()
                                autoConversionTimer = nil
                            }
                        }
                    }
                }
            }
            
        } catch {
            print("❌ [WalletListView] Error checking balances: \(error)")
        }
    }
}

// MARK: - Wallet Row
private struct WalletRow: View {
    let wallet: WalletListView.WalletItem
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            // Icon - try to use existing icons, fallback to system icon
            if wallet.iconName == "vector-icon-card" || 
               wallet.iconName == "bitcoin-icon" {
                Image(wallet.iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
            } else {
                // Fallback icon for currencies without custom icons
                Image(systemName: iconForCurrency(wallet.currency))
                    .font(.system(size: 20))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(wallet.currency)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .font(.custom("Inter", size: 16).weight(.medium))
                
                Text(wallet.displayAddress)
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .tracking(-0.25)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Copy icon on the right
            Button(action: onTap) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private func iconForCurrency(_ currency: String) -> String {
        switch currency {
        case "USDC", "USDT":
            return "dollarsign.circle"
        case "Ethereum", "ETH":
            return "e.circle"
        case "Solana", "SOL":
            return "s.circle"
        case "BNB":
            return "b.circle"
        case "Polygon", "POL":
            return "p.circle"
        default:
            return "wallet.pass"
        }
    }
}

// MARK: - Previews
#if DEBUG
#Preview {
    NavigationStack {
        WalletListView()
    }
}
#endif