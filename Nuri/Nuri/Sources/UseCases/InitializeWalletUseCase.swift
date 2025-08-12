import Foundation

protocol InitializeWalletUseCaseType {
    func execute() async -> WalletInitializationResult
    func createNewWallet() async -> Bool
    func checkWalletStatus() -> Bool
}

enum WalletInitializationResult {
    case success
    case alreadyInitialized
    case failed
    case needsRecovery
}

final class InitializeWalletUseCase: InitializeWalletUseCaseType {
    
    // MARK: - Dependencies
    
    private let walletRepository: WalletRepositoryType
    
    // MARK: - Initialization
    
    init(walletRepository: WalletRepositoryType = WalletRepository()) {
        self.walletRepository = walletRepository
    }
    
    // MARK: - Public Methods
    
    func execute() async -> WalletInitializationResult {
        print("🔄 [InitializeWalletUseCase] Starting wallet initialization...")
        
        // Check if wallet already exists
        if walletRepository.hasWallet() {
            print("✅ [InitializeWalletUseCase] Wallet already initialized")
            return .alreadyInitialized
        }
        
        // Try to initialize wallet
        let success = await walletRepository.initializeWallet()
        
        if success {
            print("✅ [InitializeWalletUseCase] Wallet initialized successfully")
            return .success
        }
        
        // If initialization failed, try to create new wallet
        print("⚠️ [InitializeWalletUseCase] Initialization failed, attempting to create new wallet...")
        let newWalletCreated = walletRepository.createNewWallet()
        
        if newWalletCreated {
            print("✅ [InitializeWalletUseCase] New wallet created successfully")
            return .success
        }
        
        print("❌ [InitializeWalletUseCase] Failed to initialize or create wallet")
        return .needsRecovery
    }
    
    func createNewWallet() async -> Bool {
        print("🔄 [InitializeWalletUseCase] Creating new wallet...")
        return walletRepository.createNewWallet()
    }
    
    func checkWalletStatus() -> Bool {
        return walletRepository.hasWallet()
    }
}