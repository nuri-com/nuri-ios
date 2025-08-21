import SwiftUI

final class BitcoinViewNavigation: ObservableObject {
    @Published var isSendViewPresented = false
    @Published var isReceiveViewPresented = false
    @Published var isTransactionsPresented = false
    @Published var isBuyBitcoinPresented = false
    @Published var isBuyViewPresented = false // For Buy Bitcoin flow
}

struct BitcoinView: View {

    @StateObject private var navigation = BitcoinViewNavigation()
    @StateObject private var walletState = WalletStateManager.shared
    @State private var isPrimaryBTC = true
    @State private var isBalanceHidden = false
    @State private var walletStatus: WalletStatus = .checking
    @State private var showWalletRecoveryAlert = false
    @State private var exchangeRate: Double = 0.0
    @State private var exchangeRateTimer: Timer?
    @State private var showStrigaDebug = false
    @State private var refreshTask: Task<Void, Never>?
    @State private var isRefreshingPrice = false
    @AppStorage("bitcoinNetwork") var bitcoinNetwork: String = "testnet3"
    
    // Cache key for exchange rate
    private let exchangeRateCacheKey = "nuri.exchangeRate.eur"
    private let exchangeRateTimestampKey = "nuri.exchangeRate.eur.timestamp"
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    enum WalletStatus {
        case checking
        case loaded
        case needsRecovery
        case failed
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NuriHeader<AnyView, AnyView>.logoAndCTA(
                    title: "",
                    cta: NetworkConfiguration.shared.shouldShowBuyButton ? NetworkConfiguration.shared.buyButtonText : "",
                    onCTA: { 
                        if NetworkConfiguration.shared.shouldShowBuyButton {
                            navigation.isBuyViewPresented = true
                        }
                    }
                )

                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        VStack(spacing: 4) {
                            AmountAndCurrency(isPrimaryBTC: $isPrimaryBTC,
                                             isBalanceHidden: $isBalanceHidden,
                                             sats: walletState.balance.total,
                                             rate: NetworkConfiguration.shared.getDisplayExchangeRate(exchangeRate))
                            SecondaryCurrencyAndAmount(isPrimaryBTC: $isPrimaryBTC,
                                                       isBalanceHidden: $isBalanceHidden,
                                                       sats: walletState.balance.total,
                                                       rate: NetworkConfiguration.shared.getDisplayExchangeRate(exchangeRate))
                        }
                        .onTapGesture {
                            isBalanceHidden.toggle()
                        }
                        HStack(spacing: 16) {
                            PrimaryHalfButton(title: "Receive", icon: "bitcoin_hand") {
                                // Just open receive view directly without authentication
                                navigation.isReceiveViewPresented = true
                            }
                            SecondaryHalfButton(title: "Send", icon: "qr_scan") {
                                ensureWalletInitialized {
                                    navigation.isSendViewPresented = true
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    Spacer()
                    HStack(spacing: 20) {
                        // Debug button removed - all transactions in unified view
                        // Button(action: {
                        //     showStrigaDebug = true
                        // }) {
                        //     Text("Debug Striga")
                        //         .font(.custom("Inter", size: 12).weight(.medium))
                        //         .foregroundColor(.blue)
                        // }
                        
                        Button(action: {
                            navigation.isTransactionsPresented = true
                        }) {
                            Image("link-icon-to-transactions")
                                .resizable()
                                .frame(width: 24, height: 13)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
        .background(NuriAsset.background.swiftUIColor)
        .onAppear {
            // Load cached exchange rate immediately
            loadCachedExchangeRate()
            // Set up periodic refresh timer
            setupExchangeRateTimer()
        }
        .onDisappear {
            // Clean up timer
            exchangeRateTimer?.invalidate()
            exchangeRateTimer = nil
            print("⏰ [BitcoinView] Exchange rate timer stopped")
        }
        .task {
            // Cancel any existing refresh task
            refreshTask?.cancel()
            
            // Start new refresh task
            refreshTask = Task {
                print("🔄 [BitcoinView] Starting refresh task...")
                // Only refresh if not already refreshing
                if !isRefreshingPrice {
                    await refreshExchangeRate()
                }
            }
        }
        .alert("Wallet Recovery", isPresented: $showWalletRecoveryAlert) {
            Button("Retry") {
                retryWalletLoad()
            }
            Button("Create New Wallet") {
                createNewWallet()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your Bitcoin wallet needs to be recovered. Would you like to retry loading your existing wallet or create a new one?")
        }
        .sheet(isPresented: $navigation.isSendViewPresented) {
            NavigationStack {
                SendView()
            }
        }
        .sheet(isPresented: $navigation.isReceiveViewPresented) {
            NavigationStack {
                ReceiveView()
            }
        }
        .sheet(isPresented: $navigation.isBuyViewPresented) {
            NavigationStack {
                BuyBitcoinFlowView()
            }
        }
        .sheet(isPresented: $navigation.isBuyBitcoinPresented) {
            BuyBitcoinView()
                .environmentObject(navigation)
        }
        .environmentObject(navigation)
        .fullScreenCover(isPresented: $navigation.isTransactionsPresented) {
            // Use the main UnifiedTransactionsView that shows both Bitcoin and Striga transactions
            UnifiedTransactionsView()
        }
        // Debug view disabled - all transactions are in UnifiedTransactionsView now
        // .fullScreenCover(isPresented: $showStrigaDebug) {
        //     StrigaTransactionsDebugView()
        // }
        .onAppear {
            // Initialize wallet on first appear
            let walletService = BitcoinWalletService.shared
            
            print("🔄 [BitcoinView] View appeared, checking wallet status...")
            print("   📱 Has wallet: \(walletService.hasWallet())")
            print("   💰 Cached balance: \(walletState.balance.total) sats (confirmed: \(walletState.balance.confirmed), pending: \(walletState.balance.pending))")
            
            // Always initialize wallet on app start (it will skip if already initialized)
            walletService.initializeWalletOnAppStart()
            
            // Trigger balance refresh after wallet is ready
            Task {
                // Wait for wallet to be fully initialized
                print("⏳ [BitcoinView] Waiting for wallet initialization...")
                let walletReady = await walletService.waitForWalletInitialization()
                
                if walletReady {
                    print("✅ [BitcoinView] Wallet is ready, refreshing balance...")
                    await walletState.getBalance(forceRefresh: true)
                    
                    // Also refresh transactions
                    print("🔄 [BitcoinView] Refreshing transactions...")
                    await walletState.getTransactions(forceRefresh: true)
                } else {
                    print("❌ [BitcoinView] Wallet initialization failed or timed out")
                    // Show cached balance if available
                    print("💰 [BitcoinView] Using cached balance: \(walletState.balance.total) sats (confirmed: \(walletState.balance.confirmed), pending: \(walletState.balance.pending))")
                }
            }
        }
    }
    
    // MARK: - Wallet Management
    private func initializeWalletInBackground() async {
        let walletService = BitcoinWalletService.shared
        
        print("🔄 [BitcoinView] Initializing wallet in background...")
        
        // Check if wallet is already initialized
        if walletService.hasWallet() {
            print("✅ [BitcoinView] Wallet already initialized")
            return
        }
        
        // Initialize wallet without Face ID
        walletService.initializeWalletOnAppStart()
        
        // Give it time to initialize
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if walletService.hasWallet() {
            print("✅ [BitcoinView] Wallet initialized successfully in background")
        } else {
            print("⚠️ [BitcoinView] Wallet initialization may have failed, will retry when needed")
        }
    }
    
    private func ensureWalletInitialized(completion: @escaping () -> Void) {
        let walletService = BitcoinWalletService.shared
        let authService = AuthenticationService.shared
        
        print("🔍 [BitcoinView] ensureWalletInitialized() called")
        
        // First check if already authenticated
        if authService.isAuthenticated && walletService.hasWallet() {
            print("✅ [BitcoinView] Already authenticated and wallet loaded")
            walletStatus = .loaded
            completion()
            return
        }
        
        // Require Face ID authentication
        authService.authenticateUser(reason: "Authenticate to access your Bitcoin wallet") { authenticated in
            guard authenticated else {
                print("❌ [BitcoinView] Authentication failed")
                walletStatus = .failed
                return
            }
            
            // Check if wallet is already initialized
            if walletService.hasWallet() {
                print("✅ [BitcoinView] Wallet already initialized after auth")
                walletStatus = .loaded
                completion()
                return
            }
            
            // Initialize wallet
            print("🔑 [BitcoinView] Initializing wallet after authentication")
            walletStatus = .checking
            
            walletService.initializeWalletOnAppStart()
            
            // Give it a moment to initialize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Check if initialization was successful
                if walletService.hasWallet() {
                    print("✅ [BitcoinView] Wallet loaded successfully")
                    walletStatus = .loaded
                    completion()
                } else {
                    print("⚠️ [BitcoinView] Wallet not loaded, attempting to create new wallet")
                    // Automatically create a new wallet instead of showing recovery
                    walletService.forceCreateNewWallet()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if walletService.hasWallet() {
                            print("✅ [BitcoinView] New wallet created successfully")
                            walletStatus = .loaded
                            completion()
                        } else {
                            print("❌ [BitcoinView] Failed to create wallet")
                            walletStatus = .needsRecovery
                            showWalletRecoveryAlert = true
                        }
                    }
                }
            }
        }
    }
    
    private func checkWalletStatus() {
        // Keep this method for manual retry scenarios
        ensureWalletInitialized {
            // Wallet is ready
        }
    }
    
    private func retryWalletLoad() {
        walletStatus = .checking
        
        // Re-initialize wallet with default user
        let walletService = BitcoinWalletService.shared
        walletService.initializeWalletOnAppStart()
        
        // Check status after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if walletService.hasWallet() {
                walletStatus = .loaded
            } else {
                walletStatus = .needsRecovery
                showWalletRecoveryAlert = true
            }
        }
    }
    
    private func createNewWallet() {
        walletStatus = .checking
        
        let walletService = BitcoinWalletService.shared
        walletService.initializeWalletOnAppStart()
        walletService.forceCreateNewWallet()
        
        // Check status after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if walletService.hasWallet() {
                walletStatus = .loaded
            } else {
                walletStatus = .failed
            }
        }
    }

    // MARK: - Exchange Rate Timer
    private func setupExchangeRateTimer() {
        print("⏰ [BitcoinView] Setting up exchange rate refresh timer (every 60s)")
        exchangeRateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                print("⏰ [BitcoinView] Timer triggered - refreshing exchange rate")
                if let price = await fetchPrice() {
                    await MainActor.run {
                        if exchangeRate != price {
                            print("💱 [BitcoinView] Timer update: €\(exchangeRate) -> €\(price)")
                        } else {
                            print("💱 [BitcoinView] Timer update: rate unchanged €\(price)")
                        }
                        exchangeRate = price
                        cacheExchangeRate(price)
                    }
                }
            }
        }
    }
    
    // MARK: - Exchange Rate Caching
    private func loadCachedExchangeRate() {
        print("💱 [BitcoinView] Loading cached exchange rate...")
        
        // Always load the last known rate if available
        let cachedRate = UserDefaults.standard.double(forKey: exchangeRateCacheKey)
        let cachedTimestamp = UserDefaults.standard.object(forKey: exchangeRateTimestampKey) as? Date ?? Date.distantPast
        
        let cacheAge = Date().timeIntervalSince(cachedTimestamp)
        let isStale = cacheAge >= cacheValidityDuration
        
        if cachedRate > 0 {
            exchangeRate = cachedRate
            print("💱 [BitcoinView] Loaded cached exchange rate: €\(cachedRate)")
            print("💱 [BitcoinView]   Cache age: \(Int(cacheAge))s (\(Int(cacheAge/60))m)")
            print("💱 [BitcoinView]   Is stale: \(isStale) (threshold: \(Int(cacheValidityDuration))s)")
        } else {
            print("⚠️ [BitcoinView] No cached exchange rate found, waiting for first fetch")
        }
    }
    
    private func cacheExchangeRate(_ rate: Double) {
        UserDefaults.standard.set(rate, forKey: exchangeRateCacheKey)
        UserDefaults.standard.set(Date(), forKey: exchangeRateTimestampKey)
        print("💱 [BitcoinView] Cached exchange rate: €\(rate)")
    }

    // MARK: - Exchange Rate
    private func refreshExchangeRate() async {
        // Prevent concurrent refreshes
        guard !isRefreshingPrice else {
            print("💱 [BitcoinView] Already refreshing price, skipping...")
            return
        }
        
        await MainActor.run {
            isRefreshingPrice = true
        }
        
        defer {
            Task { @MainActor in
                isRefreshingPrice = false
            }
        }
        
        print("💱 [BitcoinView] Refreshing exchange rate...")
        if let price = await fetchPrice() {
            await MainActor.run {
                exchangeRate = price
                cacheExchangeRate(price)
                print("💱 [BitcoinView] Exchange rate updated: €\(price)")
            }
        }
    }
    
    // MARK: - Balance
    private func refreshData() async {
        print("🔄 [BitcoinView] Starting data refresh...")
        
        // Use cached balance first, then refresh in background
        let cachedBalance = await walletState.getBalance(forceRefresh: false)
        print("💰 [BitcoinView] Using cached balance: \(cachedBalance.total) sats (confirmed: \(cachedBalance.confirmed), pending: \(cachedBalance.pending))")
        
        // Check if exchange rate needs refresh
        let cachedTimestamp = UserDefaults.standard.object(forKey: exchangeRateTimestampKey) as? Date ?? Date.distantPast
        let cacheAge = Date().timeIntervalSince(cachedTimestamp)
        let needsRefresh = cacheAge >= cacheValidityDuration
        
        print("💱 [BitcoinView] Exchange rate cache check:")
        print("💱 [BitcoinView]   Current rate: €\(exchangeRate)")
        print("💱 [BitcoinView]   Cache age: \(Int(cacheAge))s")
        print("💱 [BitcoinView]   Needs refresh: \(needsRefresh)")
        
        // Always try to fetch fresh data in background
        if let price = await fetchPrice() {
            await MainActor.run {
                print("💱 [BitcoinView] Updating exchange rate: €\(exchangeRate) -> €\(price)")
                exchangeRate = price
                cacheExchangeRate(price)
            }
        } else {
            print("⚠️ [BitcoinView] Failed to fetch new exchange rate, keeping cached: €\(exchangeRate)")
        }
        
        // Refresh wallet data in background
        print("🔄 [BitcoinView] Refreshing wallet data in background...")
        await walletState.refreshAll()
        print("✅ [BitcoinView] Data refresh completed")
    }

    private func fetchPrice() async -> Double? {
        print("💱 [BitcoinView] Fetching exchange rate from mempool.space...")
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else {
            print("❌ [BitcoinView] Invalid URL for price API")
            return nil
        }
        
        do {
            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(from: url)
            let fetchTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("💱 [BitcoinView] API Response: \(httpResponse.statusCode) in \(String(format: "%.2f", fetchTime))s")
            }
            
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eur = dict["EUR"] as? Double {
                print("💱 [BitcoinView] ✅ Fetched EUR rate: €\(eur)")
                return eur
            } else {
                print("❌ [BitcoinView] Failed to parse EUR rate from response")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [BitcoinView] Response: \(responseString.prefix(200))...")
                }
            }
        } catch {
            print("❌ [BitcoinView] Price fetch failed: \(error.localizedDescription)")
        }
        return nil
    }
}

private struct AmountAndCurrency: View {
    @Binding var isPrimaryBTC: Bool
    @Binding var isBalanceHidden: Bool
    var sats: UInt64
    var rate: Double

    var body: some View {
        let btc = Double(sats) / 100_000_000
        let eurString = String(format: "%.2f", btc * rate)
        let satsString = String(sats)

        HStack(spacing: 8) {
            if isBalanceHidden {
                Text("********")
                    .font(.brandTitle1)
            } else {
                HStack(spacing: 10) {
                    if isPrimaryBTC {
                        HStack(spacing: 4) {
                            Text("₿")
                            Text(satsString)
                        }
                    } else {
                        HStack(spacing: 0) {
                            Text("€ ")
                            Text(eurString)
                        }
                    }
                }
                .font(.brandTitle1)
            }

            Button(action: { isPrimaryBTC.toggle() }) {
                Image("transfer_vertical")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SecondaryCurrencyAndAmount: View {
    @Binding var isPrimaryBTC: Bool
    @Binding var isBalanceHidden: Bool
    var sats: UInt64
    var rate: Double

    var body: some View {
        Group {
            if isBalanceHidden {
                Text("********")
            } else {
                let btc = Double(sats) / 100_000_000
                let eurString = rate > 0 ? String(format: "%.2f", btc * rate) : "—"
                let satsString = String(sats)
                HStack(spacing: 0) {
                    if isPrimaryBTC {
                        if rate > 0 {
                            Text("€ ")
                            Text(eurString)
                        } else {
                            Text("€ —")
                        }
                    } else {
                        Text("₿ \(satsString)")
                    }
                }
            }
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(Color("PrimaryNuriBlack"))
    }
}

private struct SecondaryHalfButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Color("PrimaryNuriBlack"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color("PrimaryNuriBlack"), lineWidth: 1.4)
            )
        }
    }
}

private struct PrimaryHalfButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Color("PrimaryNuriBlack"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(hex: "#BEAAFF"))
            .cornerRadius(32)
        }
    }
}

#Preview {
    BitcoinView()
} 
