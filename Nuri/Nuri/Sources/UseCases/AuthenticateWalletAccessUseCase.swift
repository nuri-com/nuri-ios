import Foundation

protocol AuthenticateWalletAccessUseCaseType {
    func execute(reason: String) async -> Bool
    func isAuthenticated() -> Bool
    func resetAuthentication()
}

final class AuthenticateWalletAccessUseCase: AuthenticateWalletAccessUseCaseType {
    
    // MARK: - Dependencies
    
    private let authenticationService = AuthenticationService.shared
    private let walletRepository: WalletRepositoryType
    
    // MARK: - Initialization
    
    init(walletRepository: WalletRepositoryType = WalletRepository()) {
        self.walletRepository = walletRepository
    }
    
    // MARK: - Public Methods
    
    func execute(reason: String = "Authenticate to access your Bitcoin wallet") async -> Bool {
        print("🔐 [AuthenticateWalletAccessUseCase] Starting authentication...")
        
        // Check if already authenticated and wallet is ready
        if authenticationService.isAuthenticated && walletRepository.hasWallet() {
            print("✅ [AuthenticateWalletAccessUseCase] Already authenticated with wallet ready")
            return true
        }
        
        // Perform authentication
        return await withCheckedContinuation { continuation in
            authenticationService.authenticateUser(reason: reason) { [weak self] authenticated in
                guard authenticated else {
                    print("❌ [AuthenticateWalletAccessUseCase] Authentication failed")
                    continuation.resume(returning: false)
                    return
                }
                
                print("✅ [AuthenticateWalletAccessUseCase] Authentication successful")
                
                // Check if wallet needs initialization after auth
                if let self = self, !self.walletRepository.hasWallet() {
                    print("🔄 [AuthenticateWalletAccessUseCase] Initializing wallet after authentication...")
                    Task {
                        let walletReady = await self.walletRepository.initializeWallet()
                        continuation.resume(returning: walletReady)
                    }
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    func isAuthenticated() -> Bool {
        return authenticationService.isAuthenticated
    }
    
    func resetAuthentication() {
        authenticationService.resetAuthentication()
    }
}
