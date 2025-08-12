import Foundation
import StrigaAPI

/// Service responsible for automatically converting crypto balances to EUR
/// Runs in the background and checks balances periodically
@MainActor
class AutoConversionService: ObservableObject {
    
    static let shared = AutoConversionService()
    
    @Published var isMonitoring = false
    @Published var lastCheckTime: Date?
    @Published var lastConversionTime: Date?
    @Published var conversionHistory: [ConversionRecord] = []
    
    private var checkTimer: Timer?
    private let striga = StrigaService.shared
    private var failedSwapAttempts: [String: Int] = [:]
    private var lastSwapAttempt: [String: Date] = [:]
    
    // Configuration
    private let checkIntervalSeconds: TimeInterval = 60 // Check every 60 seconds
    private let minimumEURValue = 10.0 // Minimum €10 for conversion
    private let maxRetryAttempts = 3
    private let retryDelayMinutes = 30.0
    
    struct ConversionRecord {
        let date: Date
        let fromCurrency: String
        let fromAmount: String
        let toAmount: String
        let success: Bool
        let error: String?
    }
    
    private init() {
        print("[AutoConversionService] Initialized")
    }
    
    /// Start monitoring for auto-conversion
    func startMonitoring() {
        guard !isMonitoring else {
            print("[AutoConversionService] Already monitoring")
            return
        }
        
        print("[AutoConversionService] 🚀 Starting auto-conversion monitoring")
        isMonitoring = true
        
        // Cancel any existing timer
        checkTimer?.invalidate()
        
        // Start periodic checking
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkIntervalSeconds, repeats: true) { _ in
            Task { @MainActor in
                await self.checkAndConvertAllBalances()
            }
        }
        
        // Also check immediately
        Task {
            await checkAndConvertAllBalances()
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        print("[AutoConversionService] 🛑 Stopping auto-conversion monitoring")
        isMonitoring = false
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    /// Check all crypto balances and convert to EUR if above minimum
    private func checkAndConvertAllBalances() async {
        lastCheckTime = Date()
        
        // Get user and card info
        guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
              let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
            print("[AutoConversionService] No user or card ID, skipping check")
            return
        }
        
        do {
            print("[AutoConversionService] 🔍 Checking balances at \(Date())")
            
            // Get card's wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            // Get wallet details
            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
            
            // Find EUR account (destination for all conversions)
            guard let eurAccount = walletResponse.accounts.eur else {
                print("[AutoConversionService] ❌ No EUR account found")
                return
            }
            
            let eurAccountId = eurAccount.accountId
            
            // Check if EUR account is enriched (has IBAN)
            if !eurAccount.enriched {
                print("[AutoConversionService] ⚠️ EUR account not enriched (no IBAN)")
                // Try to enrich it
                do {
                    print("[AutoConversionService] Attempting to enrich EUR account...")
                    _ = try await striga.enrichAccount(.init(
                        accountId: eurAccountId,
                        userId: userId
                    ))
                    print("[AutoConversionService] ✅ EUR account enriched")
                } catch {
                    print("[AutoConversionService] ❌ Failed to enrich EUR account: \(error)")
                    return
                }
            }
            
            print("[AutoConversionService] EUR account ready (ID: \(eurAccountId))")
            
            // Check each crypto account
            let cryptoAccounts: [(String, CreateWalletResponse.Account?)] = [
                ("BTC", walletResponse.accounts.btc),
                ("ETH", walletResponse.accounts.eth),
                ("USDC", walletResponse.accounts.usdc),
                ("USDT", walletResponse.accounts.usdt),
                ("SOL", walletResponse.accounts.sol),
                ("BNB", walletResponse.accounts.bnb),
                ("POL", walletResponse.accounts.pol)
            ]
            
            for (currency, account) in cryptoAccounts {
                guard let account = account else { continue }
                
                // Check if account has balance
                let balance = account.availableBalance.amount
                guard balance != "0" && !balance.isEmpty else { continue }
                
                let balanceDouble = Double(balance) ?? 0
                guard balanceDouble > 0 else { continue }
                
                print("[AutoConversionService] Found \(currency) balance: \(balance) (smallest unit)")
                
                // Check retry limits
                if shouldSkipDueToFailures(accountId: account.accountId, currency: currency) {
                    continue
                }
                
                // Check if balance meets minimum EUR value
                if await !meetsMinimumValue(balance: balance, currency: currency) {
                    print("[AutoConversionService] \(currency) balance below €\(minimumEURValue) minimum")
                    continue
                }
                
                // Perform the swap
                await performSwap(
                    from: account,
                    to: eurAccountId,
                    amount: balance,
                    currency: currency,
                    userId: userId
                )
            }
            
        } catch {
            print("[AutoConversionService] ❌ Error checking balances: \(error)")
        }
    }
    
    /// Check if we should skip this account due to too many failures
    private func shouldSkipDueToFailures(accountId: String, currency: String) -> Bool {
        let failedAttempts = failedSwapAttempts[accountId] ?? 0
        
        if failedAttempts >= maxRetryAttempts {
            if let lastAttempt = lastSwapAttempt[accountId] {
                let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt) / 60.0
                if timeSinceLastAttempt < retryDelayMinutes {
                    print("[AutoConversionService] ⏸️ \(currency) paused (\(failedAttempts) failures, wait \(Int(retryDelayMinutes - timeSinceLastAttempt))m)")
                    return true
                } else {
                    // Reset after waiting period
                    print("[AutoConversionService] 🔄 Resetting \(currency) failure counter")
                    failedSwapAttempts[accountId] = 0
                    lastSwapAttempt.removeValue(forKey: accountId)
                }
            }
        }
        
        return false
    }
    
    /// Check if balance meets minimum EUR value
    private func meetsMinimumValue(balance: String, currency: String) async -> Bool {
        let balanceDouble = Double(balance) ?? 0
        
        // Convert to human-readable format for exchange rate check
        let formattedAmount: String
        switch currency {
        case "BTC":
            let btcAmount = balanceDouble / 100_000_000 // satoshis to BTC
            formattedAmount = String(format: "%.8f", btcAmount)
        case "ETH", "BNB", "POL":
            let amount = balanceDouble / 1_000_000_000_000_000_000 // wei to ETH
            formattedAmount = String(format: "%.18f", amount)
        case "SOL":
            let solAmount = balanceDouble / 1_000_000_000 // lamports to SOL
            formattedAmount = String(format: "%.9f", solAmount)
        case "USDC", "USDT":
            let usdAmount = balanceDouble / 100 // cents to dollars
            formattedAmount = String(format: "%.2f", usdAmount)
        default:
            formattedAmount = balance
        }
        
        // Try to get exchange rate
        do {
            let rateResponse = try await striga.getExchangeRate(
                from: currency,
                to: "EUR",
                amount: formattedAmount
            )
            
            let eurValue = Double(rateResponse.amount) ?? 0
            print("[AutoConversionService] \(currency) worth €\(String(format: "%.2f", eurValue))")
            
            return eurValue >= minimumEURValue
            
        } catch {
            print("[AutoConversionService] Could not get rate for \(currency), using fallback")
            
            // Fallback minimum amounts - increased to avoid API minimum trade errors
            let fallbackMinimums: [String: Double] = [
                "BTC": 50000,      // 50k sats ≈ €45 (Striga minimum seems to be higher)
                "ETH": 10_000_000_000_000_000, // 0.01 ETH ≈ €30
                "USDC": 2000,      // 20 USDC ≈ €18.4
                "USDT": 2000,      // 20 USDT ≈ €18.4
                "BNB": 40_000_000_000_000_000, // 0.04 BNB ≈ €24
                "POL": 20_000_000_000_000_000_000, // 20 POL ≈ €20
                "SOL": 100_000_000  // 0.1 SOL ≈ €20
            ]
            
            if let minAmount = fallbackMinimums[currency] {
                return balanceDouble >= minAmount
            }
            
            return false
        }
    }
    
    /// Perform the actual swap
    private func performSwap(from account: CreateWalletResponse.Account, to eurAccountId: String, amount: String, currency: String, userId: String) async {
        print("[AutoConversionService] 💱 Converting \(amount) \(currency) to EUR")
        
        do {
            let swapResponse = try await striga.swapCurrencies(.init(
                userId: userId,
                sourceAccountId: account.accountId,
                destinationAccountId: eurAccountId,
                amount: amount
            ))
            
            print("[AutoConversionService] ✅ Swap successful!")
            print("  - Transaction ID: \(swapResponse.id)")
            print("  - From: \(swapResponse.sourceAmount) \(currency)")
            print("  - To: \(swapResponse.destinationAmount) EUR")
            print("  - Rate: \(swapResponse.exchangeRate)")
            
            // Record success
            lastConversionTime = Date()
            conversionHistory.append(ConversionRecord(
                date: Date(),
                fromCurrency: currency,
                fromAmount: swapResponse.sourceAmount,
                toAmount: swapResponse.destinationAmount,
                success: true,
                error: nil
            ))
            
            // Reset failure counters
            failedSwapAttempts[account.accountId] = 0
            lastSwapAttempt.removeValue(forKey: account.accountId)
            
        } catch {
            print("[AutoConversionService] ❌ Swap failed: \(error)")
            
            // Check for specific error codes
            let errorString = "\(error)"
            let isMinimumTradeError = errorString.contains("31088") || 
                                      errorString.lowercased().contains("belowminimumtradevalue") ||
                                      errorString.lowercased().contains("below minimum")
            
            if isMinimumTradeError {
                print("[AutoConversionService] ⚠️ Amount below minimum trade value - stopping retries for \(currency)")
                // Set to max retries to prevent further attempts
                failedSwapAttempts[account.accountId] = maxRetryAttempts
                lastSwapAttempt[account.accountId] = Date()
            } else {
                // Regular failure handling for other errors
                let currentFailures = failedSwapAttempts[account.accountId] ?? 0
                failedSwapAttempts[account.accountId] = currentFailures + 1
                lastSwapAttempt[account.accountId] = Date()
            }
            
            // Record failure
            conversionHistory.append(ConversionRecord(
                date: Date(),
                fromCurrency: currency,
                fromAmount: amount,
                toAmount: "0",
                success: false,
                error: error.localizedDescription
            ))
            
            // Check if error is due to minimum amount (legacy check)
            if let strigaError = error as? StrigaAPI.ErrorResponse {
                if strigaError.message.lowercased().contains("minimum") {
                    // Don't retry minimum amount errors
                    failedSwapAttempts[account.accountId] = maxRetryAttempts
                }
            }
        }
    }
    
    /// Get status information
    func getStatus() -> String {
        if !isMonitoring {
            return "Auto-conversion disabled"
        }
        
        if let lastCheck = lastCheckTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            
            if let lastConversion = lastConversionTime {
                return "Active - Last check: \(formatter.string(from: lastCheck)), Last conversion: \(formatter.string(from: lastConversion))"
            } else {
                return "Active - Last check: \(formatter.string(from: lastCheck))"
            }
        }
        
        return "Active - Waiting for first check"
    }
}