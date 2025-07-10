import Foundation
import SwiftUI

/// Manages wallet state with intelligent caching and background sync
@MainActor
final class WalletStateManager: ObservableObject {
    static let shared = WalletStateManager()
    
    // MARK: - Published State
    @Published var balance: WalletBalance = WalletBalance()
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
    }
    
    private init() {
        print("🧠 [WalletStateManager] Initializing wallet state manager")
        loadPersistedBalance()
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
    
    // MARK: - Public API
    
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