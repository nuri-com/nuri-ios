import Testing
@testable import Nuri

@MainActor
struct BitcoinViewModelTests {
    
    let taskFactoryMock: TaskFactoryMock
    let exchangeRateUseCaseMock: GetExchangeRateUseCaseMock
    let initializeWalletUseCaseMock: InitializeWalletUseCaseMock
    let authenticateWalletAccessUseCaseMock: AuthenticateWalletAccessUseCaseMock
    let walletRepositoryMock: WalletRepositoryMock
    let sut: BitcoinViewModel
    
    init() {
        taskFactoryMock = TaskFactoryMock()
        exchangeRateUseCaseMock = GetExchangeRateUseCaseMock()
        initializeWalletUseCaseMock = InitializeWalletUseCaseMock()
        authenticateWalletAccessUseCaseMock = AuthenticateWalletAccessUseCaseMock()
        walletRepositoryMock = WalletRepositoryMock()
        
        sut = BitcoinViewModel(
            exchangeRateUseCase: exchangeRateUseCaseMock,
            initializeWalletUseCase: initializeWalletUseCaseMock,
            authenticateWalletAccessUseCase: authenticateWalletAccessUseCaseMock,
            walletRepository: walletRepositoryMock,
            taskFactory: taskFactoryMock
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("ViewModel initializes with cached exchange rate")
    func initializationLoadsCachedExchangeRate() async {
        // Given
        let exchangeRateMock = GetExchangeRateUseCaseMock()
        exchangeRateMock.getCachedResult = 48000.0

        // When
        let viewModel = BitcoinViewModel(
            exchangeRateUseCase: exchangeRateMock,
            initializeWalletUseCase: InitializeWalletUseCaseMock(),
            authenticateWalletAccessUseCase: AuthenticateWalletAccessUseCaseMock(),
            walletRepository: WalletRepositoryMock(),
            taskFactory: TaskFactoryMock()
        )

        // Then
        #expect(viewModel.exchangeRate == 48000.0)
    }

    @Test
    func initializationStartsPeriodicUpdatesForExchangeRate() async {
        exchangeRateUseCaseMock.startPeriodicUpdatesCallbacks.first?(123)

        // Then
        #expect(sut.exchangeRate == 123)
        #expect(exchangeRateUseCaseMock.startPeriodicUpdatesCalled == true)
    }

    // MARK: - onAppear Tests
    
    @Test("onAppear executes wallet initialization and data refresh")
    func onAppearExecutesWalletInitializationAndDataRefresh() async throws {
        // Given
        initializeWalletUseCaseMock.executeResult = .success
        walletRepositoryMock.mockBalance = WalletStateManager.WalletBalance(
            confirmed: 500000,
            pending: 10000,
            total: 510000
        )
        
        // When
        sut.onAppear()
        
        // Then - Verify task was captured
        #expect(taskFactoryMock.taskOperations.count == 1)
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Verify the operations were executed
        #expect(initializeWalletUseCaseMock.executeCallCount == 1)
        #expect(walletRepositoryMock.getBalanceCallCount == 1)
        #expect(walletRepositoryMock.getTransactionsCallCount == 1)
        
        // Verify state was updated
        #expect(sut.balance.confirmed == 500000)
        #expect(sut.balance.pending == 10000)
        #expect(sut.showWalletRecoveryAlert == false)
    }
    
    @Test("onAppear shows recovery alert when wallet needs recovery")
    func onAppearShowsRecoveryAlertWhenWalletNeedsRecovery() async throws {
        // Given
        initializeWalletUseCaseMock.executeResult = .needsRecovery
        
        // When
        sut.onAppear()
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Then
        #expect(sut.showWalletRecoveryAlert == true)
        #expect(initializeWalletUseCaseMock.executeCallCount == 1)
    }
    
    // MARK: - Send Button Tests
    
    @Test("Send button authenticates and calls completion when successful")
    func onSendButtonTappedAuthenticatesAndCallsCompletion() async throws {
        // Given
        authenticateWalletAccessUseCaseMock.executeResult = true
        var completionCalled = false
        
        // When
        sut.onSendButtonTapped {
            completionCalled = true
        }
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Then
        #expect(completionCalled == true)
        #expect(authenticateWalletAccessUseCaseMock.executeCallCount == 1)
        #expect(authenticateWalletAccessUseCaseMock.executeReason == "Authenticate to send Bitcoin")
    }
    
    @Test("Send button does not call completion when authentication fails")
    func onSendButtonTappedDoesNotCallCompletionWhenAuthFails() async throws {
        // Given
        authenticateWalletAccessUseCaseMock.executeResult = false
        var completionCalled = false
        
        // When
        sut.onSendButtonTapped {
            completionCalled = true
        }
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Then
        #expect(completionCalled == false)
        #expect(authenticateWalletAccessUseCaseMock.executeCallCount == 1)
    }
    
    // MARK: - Wallet Recovery Tests
    
    @Test("Retry wallet load shows alert when recovery needed")
    func onRetryWalletLoadShowsAlertWhenRecoveryNeeded() async throws {
        // Given
        initializeWalletUseCaseMock.executeResult = .needsRecovery
        
        // When
        sut.onRetryWalletLoad()
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Then
        #expect(sut.showWalletRecoveryAlert == true)
        #expect(initializeWalletUseCaseMock.executeCallCount == 1)
    }
    
    @Test("Create new wallet shows alert when creation fails")
    func onCreateNewWalletShowsAlertWhenCreationFails() async throws {
        // Given
        initializeWalletUseCaseMock.createNewWalletResult = false
        
        // When
        sut.onCreateNewWallet()
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Then
        #expect(sut.showWalletRecoveryAlert == true)
        #expect(initializeWalletUseCaseMock.createNewWalletCallCount == 1)
    }
    
    // MARK: - Multiple Tasks Tests
    
    @Test("Multiple tasks are captured and executed in order")
    func multipleTasksExecutedInOrder() async throws {
        // Given
        initializeWalletUseCaseMock.executeResult = .success
        walletRepositoryMock.mockBalance = WalletStateManager.WalletBalance(
            confirmed: 100000,
            pending: 0,
            total: 100000
        )
        
        // When - Trigger multiple tasks
        sut.onAppear()
        sut.onRetryWalletLoad()
        sut.onCreateNewWallet()
        
        // Then - Verify all tasks were captured
        #expect(taskFactoryMock.taskOperations.count == 3)
        
        // Execute all operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Verify operations were executed
        #expect(initializeWalletUseCaseMock.executeCallCount == 2) // onAppear + onRetryWalletLoad
        #expect(initializeWalletUseCaseMock.createNewWalletCallCount == 1)
    }
    
    // MARK: - Exchange Rate Tests
    
    @Test("onTask refreshes exchange rate")
    func onTaskRefreshesExchangeRate() async {
        // Given
        exchangeRateUseCaseMock.executeResult = 55000.0
        
        // When
        await sut.onTask()
        
        // Then
        #expect(sut.exchangeRate == 55000.0)
        #expect(exchangeRateUseCaseMock.executeCallCount == 1)
    }
    
    // MARK: - Balance Formatting Tests
    
    @Test("Formatted balance hides value when isBalanceHidden is true")
    func formattedBalanceHidesWhenIsBalanceHiddenTrue() {
        // Given
        sut.isBalanceHidden = true
        sut.balance = WalletStateManager.WalletBalance(confirmed: 100000, pending: 0, total: 100000)
        
        // Then
        #expect(sut.formattedBalance == "****")
        #expect(sut.formattedFiatBalance == "****")
    }
    
    @Test("Formatted balance shows correct values when not hidden")
    func formattedBalanceShowsCorrectValuesWhenNotHidden() {
        // Given
        sut.isBalanceHidden = false
        sut.balance = WalletStateManager.WalletBalance(
            confirmed: 100000000, // 1 BTC in satoshis
            pending: 0,
            total: 100000000
        )
        sut.exchangeRate = 50000.0
        
        // Then
        #expect(sut.formattedBalance == "100000000")
        #expect(sut.formattedFiatBalance == "€50000.00")
    }
    
    @Test("Formatted fiat balance calculates correctly for fractional BTC")
    func formattedFiatBalanceCalculatesCorrectlyForFractionalBTC() {
        // Given
        sut.isBalanceHidden = false
        sut.balance = WalletStateManager.WalletBalance(
            confirmed: 50000000, // 0.5 BTC in satoshis
            pending: 0,
            total: 50000000
        )
        sut.exchangeRate = 40000.0
        
        // Then
        #expect(sut.formattedFiatBalance == "€20000.00")
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle wallet initialization failure")
    func handleWalletInitializationFailure() async throws {
        // Given
        initializeWalletUseCaseMock.executeResult = .failed
        
        // When
        sut.onAppear()
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Then
        #expect(sut.showWalletRecoveryAlert == false) // Failed state doesn't show alert
        #expect(walletRepositoryMock.getBalanceCallCount == 1) // Still tries to get balance
    }
    
    @Test("Handle already initialized wallet")
    func handleAlreadyInitializedWallet() async throws {
        // Given
        initializeWalletUseCaseMock.executeResult = .alreadyInitialized
        walletRepositoryMock.mockBalance = WalletStateManager.WalletBalance(
            confirmed: 250000,
            pending: 0,
            total: 250000
        )
        
        // When
        sut.onAppear()
        
        // Execute the captured operations
        for operation in taskFactoryMock.taskOperations {
            try await operation()
        }
        
        // Then
        #expect(sut.showWalletRecoveryAlert == false)
        #expect(sut.balance.confirmed == 250000)
        #expect(walletRepositoryMock.getBalanceCallCount == 1)
    }
    
    @Test("Periodic updates are stopped on deinit")
    func periodicUpdatesAreStoppedOnDeinit() {
        // Given
        let exchangeRateMock = GetExchangeRateUseCaseMock()
        var viewModel: BitcoinViewModel? = BitcoinViewModel(
            exchangeRateUseCase: exchangeRateMock,
            initializeWalletUseCase: InitializeWalletUseCaseMock(),
            authenticateWalletAccessUseCase: AuthenticateWalletAccessUseCaseMock(),
            walletRepository: WalletRepositoryMock(),
            taskFactory: TaskFactoryMock()
        )
        
        // When
        viewModel = nil
        
        // Then
        #expect(exchangeRateMock.stopPeriodicUpdatesCalled == true)
    }
}
