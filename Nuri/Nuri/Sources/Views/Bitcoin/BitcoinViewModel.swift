import SwiftUI
import Foundation

@MainActor
final class BitcoinViewModel: ObservableObject {

    // MARK: - Public Variables

    @Published var isPrimaryBTC = true
    @Published var isBalanceHidden = false
    @Published var showWalletRecoveryAlert = false
    @Published var exchangeRate: Double = 0.0
    @Published var walletState = WalletStateManager.shared

    // MARK: - Variables

    private var exchangeRateTimer: Timer?
    private let exchangeRateCacheKey = "nuri.exchangeRate.eur"
    private let exchangeRateTimestampKey = "nuri.exchangeRate.eur.timestamp"
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init() {
        loadCachedExchangeRate()
        setupExchangeRateTimer()
    }
    
    deinit {
        exchangeRateTimer?.invalidate()
    }

    // MARK: - Public

    func refreshExchangeRate() async {
        print("🔄 [BitcoinViewModel] Refreshing exchange rate...")
        if let price = await fetchPrice() {
            await MainActor.run {
                exchangeRate = price
                cacheExchangeRate(price)
                print("🔄 [BitcoinViewModel] Exchange rate updated: €\(price)")
            }
        }
    }

    func refreshData() async {
        print("🔄 [BitcoinViewModel] Starting data refresh...")

        // Use cached balance first, then refresh in background
        let cachedBalance = await walletState.getBalance(forceRefresh: false)
        print("💰 [BitcoinViewModel] Using cached balance: \(cachedBalance.confirmed) sats")

        // Check if exchange rate needs refresh
        let cachedTimestamp = UserDefaults.standard.object(forKey: exchangeRateTimestampKey) as? Date ?? Date.distantPast
        let cacheAge = Date().timeIntervalSince(cachedTimestamp)
        let needsRefresh = cacheAge >= cacheValidityDuration

        print("💱 [BitcoinViewModel] Exchange rate cache check:")
        print("💱 [BitcoinViewModel]   Current rate: €\(exchangeRate)")
        print("💱 [BitcoinViewModel]   Cache age: \(Int(cacheAge))s")
        print("💱 [BitcoinViewModel]   Needs refresh: \(needsRefresh)")

        // Always try to fetch fresh data in background
        if let price = await fetchPrice() {
            await MainActor.run {
                print("🔄 [BitcoinViewModel] Updating exchange rate: €\(exchangeRate) -> €\(price)")
                exchangeRate = price
                cacheExchangeRate(price)
            }
        } else {
            print("⚠️ [BitcoinViewModel] Failed to fetch new exchange rate, keeping cached: €\(exchangeRate)")
        }

        // Refresh wallet data in background
        print("🔄 [BitcoinViewModel] Refreshing wallet data in background...")
        await walletState.refreshAll()
        print("✅ [BitcoinViewModel] Data refresh completed")
    }

    func initializeWalletInBackground() async {
        let walletService = BitcoinWalletService.shared

        print("🔄 [BitcoinViewModel] Initializing wallet in background...")

        // Check if wallet is already initialized
        if walletService.hasWallet() {
            print("✅ [BitcoinViewModel] Wallet already initialized")
            return
        }

        // Initialize wallet without Face ID
        walletService.initializeWalletOnAppStart()

        // Give it time to initialize
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        if walletService.hasWallet() {
            print("✅ [BitcoinViewModel] Wallet initialized successfully in background")
        } else {
            print("⚠️ [BitcoinViewModel] Wallet initialization may have failed, will retry when needed")
        }
    }

    func ensureWalletInitialized(completion: @escaping () -> Void) {
        let walletService = BitcoinWalletService.shared
        let authService = AuthenticationService.shared

        print("🔍 [BitcoinViewModel] ensureWalletInitialized() called")

        // First check if already authenticated
        if authService.isAuthenticated && walletService.hasWallet() {
            print("✅ [BitcoinViewModel] Already authenticated and wallet loaded")
            completion()
            return
        }

        // Require Face ID authentication
        authService.authenticateUser(reason: "Authenticate to access your Bitcoin wallet") { authenticated in
            guard authenticated else {
                print("❌ [BitcoinViewModel] Authentication failed")
                return
            }

            // Check if wallet is already initialized
            if walletService.hasWallet() {
                print("✅ [BitcoinViewModel] Wallet already initialized after auth")
                completion()
                return
            }

            // Initialize wallet
            print("🔑 [BitcoinViewModel] Initializing wallet after authentication")

            walletService.initializeWalletOnAppStart()

            // Give it a moment to initialize
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Check if initialization was successful
                if walletService.hasWallet() {
                    print("✅ [BitcoinViewModel] Wallet loaded successfully")
                    completion()
                } else {
                    print("⚠️ [BitcoinViewModel] Wallet not loaded, attempting to create new wallet")
                    // Automatically create a new wallet instead of showing recovery
                    walletService.forceCreateNewWallet()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if walletService.hasWallet() {
                            print("✅ [BitcoinViewModel] New wallet created successfully")
                            completion()
                        } else {
                            print("❌ [BitcoinViewModel] Failed to create wallet")
                            self.showWalletRecoveryAlert = true
                        }
                    }
                }
            }
        }
    }

    func retryWalletLoad() {
        let walletService = BitcoinWalletService.shared
        walletService.initializeWalletOnAppStart()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if walletService.hasWallet() {
            } else {
                self.showWalletRecoveryAlert = true
            }
        }
    }

    func createNewWallet() {
        let walletService = BitcoinWalletService.shared
        walletService.initializeWalletOnAppStart()
        walletService.forceCreateNewWallet()
    }

    func onAppear() {
        // Initialize wallet on first appear
        let walletService = BitcoinWalletService.shared

        print("🔄 [BitcoinView] View appeared, checking wallet status...")
        print("   📱 Has wallet: \(walletService.hasWallet())")
        print("   💰 Cached balance: \(walletState.balance.confirmed) sats")

        // Always initialize wallet on app start (it will skip if already initialized)
        walletService.initializeWalletOnAppStart()

        // Trigger balance refresh after wallet is ready
        Task {
            // Wait for wallet to be fully initialized
            print("⏳ [BitcoinView] Waiting for wallet initialization...")
            let walletReady = await walletService.waitForWalletInitialization()

            if walletReady {
                print("✅ [BitcoinView] Wallet is ready, refreshing balance...")
                _ = await walletState.getBalance(forceRefresh: true)

                // Also refresh transactions
                print("🔄 [BitcoinView] Refreshing transactions...")
                _ = await walletState.getTransactions(forceRefresh: true)
            } else {
                print("❌ [BitcoinView] Wallet initialization failed or timed out")
                // Show cached balance if available
                print("💰 [BitcoinView] Using cached balance: \(walletState.balance.confirmed) sats")
            }
        }
    }

    func onTask() async {
        print("🔄 [BitcoinView] Starting refresh task...")
        // The WalletStateManager already handles initial balance fetch
        // Just refresh exchange rate here
        await refreshExchangeRate()
    }

    // MARK: - Private

    private func setupExchangeRateTimer() {
        print("⏰ [BitcoinViewModel] Setting up exchange rate refresh timer (every 60s)")
        exchangeRateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                print("⏰ [BitcoinViewModel] Timer triggered - refreshing exchange rate")
                if let price = await self.fetchPrice() {
                    await MainActor.run {
                        if self.exchangeRate != price {
                            print("💱 [BitcoinViewModel] Timer update: €\(self.exchangeRate) -> €\(price)")
                        } else {
                            print("💱 [BitcoinViewModel] Timer update: rate unchanged €\(price)")
                        }
                        self.exchangeRate = price
                        self.cacheExchangeRate(price)
                    }
                }
            }
        }
    }
    
    private func loadCachedExchangeRate() {
        print("💱 [BitcoinViewModel] Loading cached exchange rate...")
        
        // Always load the last known rate if available
        let cachedRate = UserDefaults.standard.double(forKey: exchangeRateCacheKey)
        let cachedTimestamp = UserDefaults.standard.object(forKey: exchangeRateTimestampKey) as? Date ?? Date.distantPast
        
        let cacheAge = Date().timeIntervalSince(cachedTimestamp)
        let isStale = cacheAge >= cacheValidityDuration
        
        if cachedRate > 0 {
            exchangeRate = cachedRate
            print("💱 [BitcoinViewModel] Loaded cached exchange rate: €\(cachedRate)")
            print("💱 [BitcoinViewModel]   Cache age: \(Int(cacheAge))s (\(Int(cacheAge/60))m)")
            print("💱 [BitcoinViewModel]   Is stale: \(isStale) (threshold: \(Int(cacheValidityDuration))s)")
        } else {
            print("⚠️ [BitcoinViewModel] No cached exchange rate found, waiting for first fetch")
        }
    }
    
    private func cacheExchangeRate(_ rate: Double) {
        UserDefaults.standard.set(rate, forKey: exchangeRateCacheKey)
        UserDefaults.standard.set(Date(), forKey: exchangeRateTimestampKey)
        print("💱 [BitcoinViewModel] Cached exchange rate: €\(rate)")
    }

    private func fetchPrice() async -> Double? {
        print("🔄 [BitcoinViewModel] Fetching exchange rate from mempool.space...")
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else {
            print("❌ [BitcoinViewModel] Invalid URL for price API")
            return nil
        }
        
        do {
            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(from: url)
            let fetchTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔄 [BitcoinViewModel] API Response: \(httpResponse.statusCode) in \(String(format: "%.2f", fetchTime))s")
            }
            
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eur = dict["EUR"] as? Double {
                print("🔄 [BitcoinViewModel] ✅ Fetched EUR rate: €\(eur)")
                return eur
            } else {
                print("❌ [BitcoinViewModel] Failed to parse EUR rate from response")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [BitcoinViewModel] Response: \(responseString.prefix(200))...")
                }
            }
        } catch {
            print("❌ [BitcoinViewModel] Price fetch failed: \(error.localizedDescription)")
        }
        return nil
    }
}
