import Foundation

protocol WalletRepositoryType {
    func initializeWallet() async -> Bool
    func hasWallet() -> Bool
    func createNewWallet() -> Bool
    func getBalance(forceRefresh: Bool) async -> WalletStateManager.WalletBalance
    func getTransactions(forceRefresh: Bool) async -> [WalletStateManager.CachedTransaction]
    func refreshAllData() async
}

final class WalletRepository: WalletRepositoryType {
    
    // MARK: - Dependencies
    
    private let walletService = BitcoinWalletService.shared
    private let walletStateManager = WalletStateManager.shared
    
    // MARK: - Public Methods
    
    func initializeWallet() async -> Bool {
        print("🔄 [WalletRepository] Initializing wallet...")
        
        if walletService.hasWallet() {
            print("✅ [WalletRepository] Wallet already initialized")
            return true
        }
        
        walletService.initializeWalletOnAppStart()
        
        // Wait for initialization
        let isReady = await walletService.waitForWalletInitialization()
        
        if isReady {
            print("✅ [WalletRepository] Wallet initialized successfully")
        } else {
            print("❌ [WalletRepository] Wallet initialization failed")
        }
        
        return isReady
    }
    
    func hasWallet() -> Bool {
        return walletService.hasWallet()
    }
    
    func createNewWallet() -> Bool {
        print("🔄 [WalletRepository] Creating new wallet...")
        walletService.forceCreateNewWallet()
        
        let hasWallet = walletService.hasWallet()
        if hasWallet {
            print("✅ [WalletRepository] New wallet created successfully")
        } else {
            print("❌ [WalletRepository] Failed to create new wallet")
        }
        
        return hasWallet
    }
    
    func getBalance(forceRefresh: Bool) async -> WalletStateManager.WalletBalance {
        print("💰 [WalletRepository] Getting balance (forceRefresh: \(forceRefresh))")
        return await walletStateManager.getBalance(forceRefresh: forceRefresh)
    }
    
    func getTransactions(forceRefresh: Bool) async -> [WalletStateManager.CachedTransaction] {
        print("📝 [WalletRepository] Getting transactions (forceRefresh: \(forceRefresh))")
        return await walletStateManager.getTransactions(forceRefresh: forceRefresh)
    }
    
    func refreshAllData() async {
        print("🔄 [WalletRepository] Refreshing all wallet data...")
        await walletStateManager.refreshAll()
        print("✅ [WalletRepository] All wallet data refreshed")
    }
}
