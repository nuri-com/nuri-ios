import Foundation
@testable import Nuri

@MainActor
final class WalletRepositoryMock: WalletRepositoryType {
    var initializeWalletCallCount = 0
    var initializeWalletResult = true
    var hasWalletCallCount = 0
    var hasWalletResult = true
    var createNewWalletCallCount = 0
    var createNewWalletResult = true
    var getBalanceCallCount = 0
    var getTransactionsCallCount = 0
    var refreshAllDataCallCount = 0
    
    var mockBalance = WalletStateManager.WalletBalance(confirmed: 100000, pending: 0, total: 100000)
    var mockTransactions: [WalletStateManager.CachedTransaction] = []
    
    func initializeWallet() async -> Bool {
        initializeWalletCallCount += 1
        return initializeWalletResult
    }
    
    func hasWallet() -> Bool {
        hasWalletCallCount += 1
        return hasWalletResult
    }
    
    func createNewWallet() -> Bool {
        createNewWalletCallCount += 1
        return createNewWalletResult
    }
    
    func getBalance(forceRefresh: Bool) async -> WalletStateManager.WalletBalance {
        getBalanceCallCount += 1
        return mockBalance
    }
    
    func getTransactions(forceRefresh: Bool) async -> [WalletStateManager.CachedTransaction] {
        getTransactionsCallCount += 1
        return mockTransactions
    }
    
    func refreshAllData() async {
        refreshAllDataCallCount += 1
    }
}