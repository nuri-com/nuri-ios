import Foundation
import SwiftUI
import BitcoinDevKit

/// Manages wallet state with intelligent caching and background sync
@MainActor
final class WalletStateManager: ObservableObject {
    static let shared = WalletStateManager()
    
    // MARK: - Published State
    @Published var balance: WalletBalance = WalletBalance()
    @Published var transactions: [CachedTransaction] = []
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - Private Properties
    private let walletService = BitcoinWalletService.shared
    private var syncTimer: Timer?
    private var pendingTransactions: Set<String> = []
    
    // MARK: - Configuration
    private let backgroundSyncInterval: TimeInterval = 30 // 30 seconds
    private let maxCacheAge: TimeInterval = 900 // 15 minutes
    
    // MARK: - Persistent Cache Keys
    private enum CacheKeys {
        static let balanceConfirmed = "nuri.wallet.balance.confirmed"
        static let balancePending = "nuri.wallet.balance.pending"
        static let balanceTotal = "nuri.wallet.balance.total"
        static let balanceLastUpdated = "nuri.wallet.balance.lastUpdated"
        static let pendingTransactionsList = "nuri.wallet.pendingTransactions"
        static let transactionsList = "nuri.wallet.transactions.list"
        static let transactionsLastUpdated = "nuri.wallet.transactions.lastUpdated"
    }
    
    private init() {
        print("🧠 [WalletStateManager] Initializing wallet state manager")
        loadPersistedBalance()
        loadPersistedTransactions()
        loadPersistedPendingTransactions()
        setupBackgroundSync()
    }
    
    // MARK: - Data Models
    struct WalletBalance {
        var confirmed: UInt64 = 0
        var pending: UInt64 = 0
        var total: UInt64 = 0
        var lastUpdated: Date = Date()
        
        var isStale: Bool {
            Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
        }
    }
    
    struct CachedTransaction: Identifiable, Codable {
        let id = UUID()
        let txId: String
        let type: TransactionType
        let amountSats: UInt64
        let eurAmount: Double
        let eurRate: Double  // Exchange rate at time of transaction
        let date: Date
        let isConfirmed: Bool
        let blockTime: UInt64?
        
        enum TransactionType: String, Codable {
            case send = "Send Bitcoin"
            case receive = "Receive Bitcoin"
        }
        
        // For UI display
        var iconName: String {
            switch type {
            case .send:
                return "list-item-icon-paperplane_send"  // Plain/error icon as requested
            case .receive:
                return "bitcoin_hand"  // Same as "Bought Bitcoin" icon
            }
        }
        
        var amountWithSign: Int64 {
            switch type {
            case .send:
                return -Int64(amountSats)
            case .receive:
                return Int64(amountSats)
            }
        }
        
        var eurAmountWithSign: Double {
            switch type {
            case .send:
                return -eurAmount
            case .receive:
                return eurAmount
            }
        }
        
        var displayDate: String {
            let now = Date()
            let timeInterval = now.timeIntervalSince(date)
            
            if timeInterval < 3600 { // Less than 1 hour
                let minutes = Int(timeInterval / 60)
                return "\(minutes) min ago"
            } else if timeInterval < 86400 { // Less than 24 hours
                let hours = Int(timeInterval / 3600)
                return "\(hours) hours ago"
            } else if timeInterval < 604800 { // Less than 7 days
                let days = Int(timeInterval / 86400)
                return "\(days) days ago"
            } else {
                // Use actual date format
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        }
        
        var statusText: String? {
            return isConfirmed ? nil : "Pending"
        }
    }
    
    // MARK: - Public API
    
    /// Get cached transactions with smart refresh
    func getTransactions(forceRefresh: Bool = false) async -> [CachedTransaction] {
        print("📋 [WalletStateManager] getTransactions called (forceRefresh: \(forceRefresh))")
        print("📋 [WalletStateManager] Current cached transactions: \(transactions.count)")
        
        // Check if we need to refresh transactions
        let transactionsStale = isTransactionsStale()
        
        if !forceRefresh && !transactionsStale && !transactions.isEmpty {
            print("📋 [WalletStateManager] Returning cached transactions: \(transactions.count) items")
            return transactions
        }
        
        // Fetch fresh transactions
        print("📋 [WalletStateManager] Cache stale or refresh forced, syncing transactions...")
        await syncTransactions()
        return transactions
    }

    /// Get current balance with smart caching
    func getBalance(forceRefresh: Bool = false) async -> WalletBalance {
        print("💰 [WalletStateManager] getBalance called (forceRefresh: \(forceRefresh))")
        print("💰 [WalletStateManager] Current cached balance: \(balance.confirmed) confirmed, \(balance.pending) pending")
        print("💰 [WalletStateManager] Cache age: \(Date().timeIntervalSince(balance.lastUpdated))s, isStale: \(balance.isStale)")
        
        // Return cached balance if fresh and not forced
        if !forceRefresh && !balance.isStale {
            print("💰 [WalletStateManager] Returning cached balance: \(balance.confirmed) sats (fresh cache)")
            return balance
        }
        
        // Fetch fresh balance
        print("💰 [WalletStateManager] Cache stale or refresh forced, syncing...")
        await syncBalance()
        return balance
    }
    
    /// Refresh all wallet data
    func refreshAll() async {
        print("🔄 [WalletStateManager] Full wallet refresh requested")
        isLoading = true
        
        await syncBalance()
        await syncTransactions()
        
        isLoading = false
        lastSyncTime = Date()
        print("✅ [WalletStateManager] Full refresh completed")
    }
    
    /// Add a pending outgoing transaction immediately
    func addPendingTransaction(txId: String, amount: UInt64, recipientAddress: String, fee: UInt64) {
        print("➕ [WalletStateManager] Adding pending transaction: \(txId)")
        print("➕ [WalletStateManager]   Amount: \(amount) sats, Fee: \(fee) sats")
        
        // Immediately update balance (optimistic update)
        let totalDeducted = amount + fee
        let previousConfirmed = balance.confirmed
        balance.confirmed = balance.confirmed >= totalDeducted ? balance.confirmed - totalDeducted : 0
        balance.total = balance.confirmed + balance.pending
        balance.lastUpdated = Date()
        
        // Add to pending transactions
        pendingTransactions.insert(txId)
        
        print("💰 [WalletStateManager] Balance updated optimistically:")
        print("💰 [WalletStateManager]   Previous confirmed: \(previousConfirmed) sats")
        print("💰 [WalletStateManager]   New confirmed: \(balance.confirmed) sats")
        print("💰 [WalletStateManager]   Amount deducted: \(totalDeducted) sats")
        
        // Persist the optimistic update
        persistBalance(balance)
        persistPendingTransactions()
        
        // Schedule a sync to get actual network state
        Task {
            print("⏱️ [WalletStateManager] Scheduling sync in 2 seconds to confirm transaction...")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await syncBalance()
        }
    }
    
    /// Get available spending balance (confirmed only)
    var availableBalance: UInt64 {
        balance.confirmed
    }
    
    /// Check if we have sufficient funds for a transaction
    func hasSufficientFunds(amount: UInt64, fee: UInt64 = 0) -> Bool {
        let required = amount + fee
        return balance.confirmed >= required
    }
    
    // MARK: - Private Methods
    
    private func syncBalance() async {
        print("🔄 [WalletStateManager] Starting balance sync...")
        print("🔄 [WalletStateManager] Current balance: \(balance.confirmed) confirmed, \(balance.pending) pending")
        
        DispatchQueue.main.async {
            self.isSyncing = true
        }
        
        guard let detailedBalance = await walletService.getDetailedBalance() else {
            print("❌ [WalletStateManager] Failed to fetch balance from wallet service")
            DispatchQueue.main.async {
                self.syncError = "Failed to fetch balance"
                self.isSyncing = false
            }
            return
        }
        
        print("📡 [WalletStateManager] Received balance from network:")
        print("📡 [WalletStateManager]   Confirmed: \(detailedBalance.confirmed) sats")
        print("📡 [WalletStateManager]   Pending: \(detailedBalance.pending) sats")
        print("📡 [WalletStateManager]   Total: \(detailedBalance.total) sats")
        
        let newBalance = WalletBalance(
            confirmed: detailedBalance.confirmed,
            pending: detailedBalance.pending,
            total: detailedBalance.total,
            lastUpdated: Date()
        )
        
        // Check if balance changed
        let balanceChanged = newBalance.confirmed != balance.confirmed || 
                           newBalance.pending != balance.pending
        
        DispatchQueue.main.async {
            self.balance = newBalance
            self.syncError = nil
            self.isSyncing = false
            self.lastSyncTime = Date()
        }
        
        // Persist the new balance
        persistBalance(newBalance)
        
        if balanceChanged {
            print("💰 [WalletStateManager] ✅ Balance updated and persisted:")
            print("💰 [WalletStateManager]   Previous: \(balance.confirmed) → \(newBalance.confirmed) confirmed")
            print("💰 [WalletStateManager]   Previous: \(balance.pending) → \(newBalance.pending) pending")
        } else {
            print("💰 [WalletStateManager] ✅ Balance unchanged: \(newBalance.confirmed) confirmed, \(newBalance.pending) pending")
        }
    }
    
    private func syncTransactions() async {
        print("📋 [WalletStateManager] Starting transaction sync...")
        print("📋 [WalletStateManager] Current cached transactions: \(transactions.count)")
        
        DispatchQueue.main.async {
            self.isSyncing = true
        }
        
        guard let bdkTransactions = await walletService.getTransactions() else {
            print("❌ [WalletStateManager] Failed to fetch transactions from wallet service")
            DispatchQueue.main.async {
                self.syncError = "Failed to fetch transactions"
                self.isSyncing = false
            }
            return
        }
        
        print("📡 [WalletStateManager] Received \(bdkTransactions.count) transactions from BDK")
        
        // Get current exchange rate for transactions without historical rate
        let currentExchangeRate = await fetchCurrentExchangeRate()
        print("💱 [WalletStateManager] Current exchange rate: \(currentExchangeRate) EUR/BTC")
        
        var cachedTransactions: [CachedTransaction] = []
        
        for (index, bdkTx) in bdkTransactions.enumerated() {
            let txId = bdkTx.transaction.computeTxid()
            print("📄 [WalletStateManager] Processing transaction \(index + 1): \(txId)")
            
            // Get sent/received amounts to determine transaction type
            guard let wallet = walletService.getWallet() else { continue }
            let sentReceived = wallet.sentAndReceived(tx: bdkTx.transaction)
            
            let sent = sentReceived.sent.toSat()
            let received = sentReceived.received.toSat()
            
            print("📄 [WalletStateManager]   Sent: \(sent) sats, Received: \(received) sats")
            
            // Determine transaction type and amount
            let (type, amountSats): (CachedTransaction.TransactionType, UInt64)
            if sent == 0 && received > 0 {
                type = .receive
                amountSats = received
            } else if sent > 0 {
                type = .send
                amountSats = sent > received ? sent - received : sent
            } else {
                print("📄 [WalletStateManager]   Skipping transaction with no clear direction")
                continue
            }
            
            // Get confirmation status and timing
            let (isConfirmed, blockTime) = getTransactionInfo(chainPosition: bdkTx.chainPosition)
            let date = getTransactionDate(chainPosition: bdkTx.chainPosition)
            
            print("📄 [WalletStateManager]   Type: \(type.rawValue)")
            print("📄 [WalletStateManager]   Amount: \(amountSats) sats")
            print("📄 [WalletStateManager]   Confirmed: \(isConfirmed)")
            print("📄 [WalletStateManager]   Date: \(date)")
            
            // Check if we have cached exchange rate for this transaction
            let exchangeRate = getHistoricalExchangeRate(for: date) ?? currentExchangeRate
            let eurAmount = Double(amountSats) * exchangeRate / 100_000_000.0 // Convert sats to BTC then to EUR
            
            print("📄 [WalletStateManager]   Exchange rate: \(exchangeRate) EUR/BTC")
            print("📄 [WalletStateManager]   EUR amount: \(eurAmount)")
            
            let cachedTx = CachedTransaction(
                txId: txId,
                type: type,
                amountSats: amountSats,
                eurAmount: eurAmount,
                eurRate: exchangeRate,
                date: date,
                isConfirmed: isConfirmed,
                blockTime: blockTime
            )
            
            cachedTransactions.append(cachedTx)
        }
        
        // Sort by date (newest first)
        cachedTransactions.sort { $0.date > $1.date }
        
        print("📋 [WalletStateManager] ✅ Processed \(cachedTransactions.count) transactions")
        
        DispatchQueue.main.async {
            self.transactions = cachedTransactions
            self.isSyncing = false
        }
        
        // Persist transactions
        persistTransactions(cachedTransactions)
        
        print("📋 [WalletStateManager] ✅ Transactions updated and persisted")
    }
    
    private func isDataStale() -> Bool {
        guard let lastSync = lastSyncTime else { return true }
        return Date().timeIntervalSince(lastSync) > maxCacheAge
    }
    
    private func setupBackgroundSync() {
        print("⏰ [WalletStateManager] Setting up background sync timer")
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: backgroundSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.backgroundSync()
            }
        }
    }
    
    private func backgroundSync() async {
        // Only sync if app is active and we have pending transactions or stale data
        guard !pendingTransactions.isEmpty || isDataStale() else {
            print("⏰ [WalletStateManager] Background sync skipped - data is fresh and no pending transactions")
            return
        }
        
        print("🔄 [WalletStateManager] Background sync triggered")
        print("🔄 [WalletStateManager]   Pending transactions: \(pendingTransactions.count)")
        print("🔄 [WalletStateManager]   Data is stale: \(isDataStale())")
        await syncBalance()
    }
    
    deinit {
        syncTimer?.invalidate()
        print("🧠 [WalletStateManager] Deinitializing wallet state manager")
    }
    
    // MARK: - Persistence Methods
    
    private func persistBalance(_ balance: WalletBalance) {
        print("💾 [WalletStateManager] Persisting balance to UserDefaults...")
        
        UserDefaults.standard.set(balance.confirmed, forKey: CacheKeys.balanceConfirmed)
        UserDefaults.standard.set(balance.pending, forKey: CacheKeys.balancePending)
        UserDefaults.standard.set(balance.total, forKey: CacheKeys.balanceTotal)
        UserDefaults.standard.set(balance.lastUpdated, forKey: CacheKeys.balanceLastUpdated)
        
        print("💾 [WalletStateManager] ✅ Balance persisted: \(balance.confirmed) confirmed, \(balance.pending) pending")
    }
    
    private func loadPersistedBalance() {
        print("📱 [WalletStateManager] Loading persisted balance from UserDefaults...")
        
        let confirmed = UserDefaults.standard.object(forKey: CacheKeys.balanceConfirmed) as? UInt64 ?? 0
        let pending = UserDefaults.standard.object(forKey: CacheKeys.balancePending) as? UInt64 ?? 0
        let total = UserDefaults.standard.object(forKey: CacheKeys.balanceTotal) as? UInt64 ?? 0
        let lastUpdated = UserDefaults.standard.object(forKey: CacheKeys.balanceLastUpdated) as? Date ?? Date.distantPast
        
        if confirmed > 0 || pending > 0 {
            balance = WalletBalance(
                confirmed: confirmed,
                pending: pending,
                total: total,
                lastUpdated: lastUpdated
            )
            
            let cacheAge = Date().timeIntervalSince(lastUpdated)
            print("📱 [WalletStateManager] ✅ Loaded persisted balance:")
            print("📱 [WalletStateManager]   Confirmed: \(confirmed) sats")
            print("📱 [WalletStateManager]   Pending: \(pending) sats")
            print("📱 [WalletStateManager]   Total: \(total) sats")
            print("📱 [WalletStateManager]   Cache age: \(cacheAge)s")
            print("📱 [WalletStateManager]   Is stale: \(balance.isStale)")
        } else {
            print("📱 [WalletStateManager] No persisted balance found, starting with 0")
        }
    }
    
    private func loadPersistedPendingTransactions() {
        if let persistedTransactions = UserDefaults.standard.array(forKey: CacheKeys.pendingTransactionsList) as? [String] {
            pendingTransactions = Set(persistedTransactions)
            print("📱 [WalletStateManager] Loaded \(pendingTransactions.count) persisted pending transactions")
        }
    }
    
    private func persistPendingTransactions() {
        UserDefaults.standard.set(Array(pendingTransactions), forKey: CacheKeys.pendingTransactionsList)
        print("💾 [WalletStateManager] Persisted \(pendingTransactions.count) pending transactions")
    }
    
    // MARK: - Transaction Persistence Methods
    
    private func persistTransactions(_ transactions: [CachedTransaction]) {
        print("💾 [WalletStateManager] Persisting \(transactions.count) transactions to UserDefaults...")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(transactions)
            UserDefaults.standard.set(data, forKey: CacheKeys.transactionsList)
            UserDefaults.standard.set(Date(), forKey: CacheKeys.transactionsLastUpdated)
            print("💾 [WalletStateManager] ✅ Transactions persisted successfully")
        } catch {
            print("❌ [WalletStateManager] Failed to persist transactions: \(error)")
        }
    }
    
    private func loadPersistedTransactions() {
        print("📱 [WalletStateManager] Loading persisted transactions from UserDefaults...")
        
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.transactionsList) else {
            print("📱 [WalletStateManager] No persisted transactions found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let persistedTransactions = try decoder.decode([CachedTransaction].self, from: data)
            let lastUpdated = UserDefaults.standard.object(forKey: CacheKeys.transactionsLastUpdated) as? Date ?? Date.distantPast
            
            transactions = persistedTransactions
            
            let cacheAge = Date().timeIntervalSince(lastUpdated)
            print("📱 [WalletStateManager] ✅ Loaded \(persistedTransactions.count) persisted transactions")
            print("📱 [WalletStateManager]   Cache age: \(cacheAge)s")
            print("📱 [WalletStateManager]   Is stale: \(isTransactionsStale())")
        } catch {
            print("❌ [WalletStateManager] Failed to load persisted transactions: \(error)")
        }
    }
    
    // MARK: - Transaction Helper Methods
    
    private func isTransactionsStale() -> Bool {
        guard let lastUpdated = UserDefaults.standard.object(forKey: CacheKeys.transactionsLastUpdated) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastUpdated) > maxCacheAge
    }
    
    private func getTransactionInfo(chainPosition: ChainPosition) -> (isConfirmed: Bool, blockTime: UInt64?) {
        switch chainPosition {
        case .confirmed(let blockTime, _):
            return (true, UInt64(blockTime.blockId.height))
        case .unconfirmed(_):
            return (false, nil)
        }
    }
    
    private func getTransactionDate(chainPosition: ChainPosition) -> Date {
        switch chainPosition {
        case .confirmed(let blockTime, _):
            return blockTime.confirmationTime.toDate()
        case .unconfirmed(let timestamp):
            return timestamp?.toDate() ?? Date()
        }
    }
    
    private func fetchCurrentExchangeRate() async -> Double {
        // Reuse the same API as the main app
        do {
            let url = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=BTC")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["data"] as? [String: Any],
               let rates = responseData["rates"] as? [String: String],
               let eurRate = rates["EUR"],
               let rate = Double(eurRate) {
                print("💱 [WalletStateManager] Fetched current EUR rate: \(rate)")
                return rate
            }
        } catch {
            print("❌ [WalletStateManager] Failed to fetch exchange rate: \(error)")
        }
        
        // Fallback rate
        print("💱 [WalletStateManager] Using fallback EUR rate: 50000.0")
        return 50000.0
    }
    
    private func getHistoricalExchangeRate(for date: Date) -> Double? {
        // For now, we don't have historical rates stored
        // In the future, we could cache rates by date or use a historical API
        return nil
    }
}

// MARK: - Convenience Extensions
extension WalletStateManager {
    /// Get pending transactions count
    var pendingTransactionCount: Int {
        pendingTransactions.count
    }
    
    /// Check if wallet is syncing (uses published isSyncing property)
    
    /// Get formatted balance string
    var formattedBalance: String {
        "₿ \(balance.confirmed)"
    }
}