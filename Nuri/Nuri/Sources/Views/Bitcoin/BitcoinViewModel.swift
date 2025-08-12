import SwiftUI
import Foundation

@MainActor
final class BitcoinViewModel: ObservableObject {

    // MARK: - UI State
    
    @Published var isPrimaryBTC = true
    @Published var isBalanceHidden = false
    @Published var showWalletRecoveryAlert = false
    @Published var exchangeRate: Double = 0.0
    @Published var balance: WalletStateManager.WalletBalance = .init(confirmed: 0, pending: 0, total: 0)
    @Published var transactions: [WalletStateManager.CachedTransaction] = []
    
    // MARK: - Dependencies
    
    private let exchangeRateUseCase: GetExchangeRateUseCaseType
    private let initializeWalletUseCase: InitializeWalletUseCaseType
    private let authenticateWalletAccessUseCase: AuthenticateWalletAccessUseCaseType
    private let walletRepository: WalletRepositoryType
    private let taskFactory: TaskFactoryType
    
    // MARK: - Initialization
    
    init(
        exchangeRateUseCase: GetExchangeRateUseCaseType = GetExchangeRateUseCase(),
        initializeWalletUseCase: InitializeWalletUseCaseType = InitializeWalletUseCase(),
        authenticateWalletAccessUseCase: AuthenticateWalletAccessUseCaseType = AuthenticateWalletAccessUseCase(),
        walletRepository: WalletRepositoryType = WalletRepository(),
        taskFactory: TaskFactoryType = TaskFactory()
    ) {
        self.exchangeRateUseCase = exchangeRateUseCase
        self.initializeWalletUseCase = initializeWalletUseCase
        self.authenticateWalletAccessUseCase = authenticateWalletAccessUseCase
        self.walletRepository = walletRepository
        self.taskFactory = taskFactory
        
        setupInitialState()
    }
    
    deinit {
        exchangeRateUseCase.stopPeriodicUpdates()
    }
    
    // MARK: - Setup
    
    private func setupInitialState() {
        // Load cached exchange rate
        exchangeRate = exchangeRateUseCase.getCached(currency: "EUR")
        
        // Start periodic exchange rate updates
        exchangeRateUseCase.startPeriodicUpdates(currency: "EUR", interval: 60) { [weak self] rate in
            self?.exchangeRate = rate
        }
    }
    
    // MARK: - View Actions
    
    func onAppear() {
        taskFactory.task {
            await self.initializeWallet()
            await self.refreshWalletData()
        }
    }
    
    func onTask() async {
        await refreshExchangeRate()
    }
    
    func onSendButtonTapped(completion: @escaping () -> Void) {
        taskFactory.task {
            let authenticated = await self.authenticateWalletAccessUseCase.execute(reason: "Authenticate to send Bitcoin")
            if authenticated {
                await MainActor.run {
                    completion()
                }
            }
        }
    }
    
    func onRetryWalletLoad() {
        taskFactory.task {
            let result = await self.initializeWalletUseCase.execute()
            if result == .needsRecovery {
                await MainActor.run {
                    self.showWalletRecoveryAlert = true
                }
            }
        }
    }
    
    func onCreateNewWallet() {
        taskFactory.task {
            let success = await self.initializeWalletUseCase.createNewWallet()
            if !success {
                await self.showWalletRecovery()
            }
        }
    }
    
    // MARK: - Private Methods

    private func showWalletRecovery() async {
        showWalletRecoveryAlert = true
    }

    private func initializeWallet() async {
        let result = await initializeWalletUseCase.execute()
        
        switch result {
        case .needsRecovery:
            showWalletRecoveryAlert = true
        case .success, .alreadyInitialized:
            // Wallet is ready
            break
        case .failed:
            // Handle failure if needed
            break
        }
    }
    
    private func refreshWalletData() async {
        // Get balance
        balance = await walletRepository.getBalance(forceRefresh: true)
        
        // Get transactions
        transactions = await walletRepository.getTransactions(forceRefresh: true)
    }
    
    private func refreshExchangeRate() async {
        let rate = await exchangeRateUseCase.execute(currency: "EUR")
        exchangeRate = rate
    }
    
    // MARK: - Computed Properties for UI
    
    var formattedBalance: String {
        if isBalanceHidden {
            return "****"
        }
        return "\(balance.confirmed)"
    }
    
    var formattedFiatBalance: String {
        if isBalanceHidden {
            return "****"
        }
        let btcAmount = Double(balance.confirmed) / 100_000_000
        let fiatValue = btcAmount * exchangeRate
        return String(format: "€%.2f", fiatValue)
    }
}
