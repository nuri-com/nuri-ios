import Testing
@testable import Nuri

@MainActor
struct InitializeWalletUseCaseTests {
    
    let walletRepositoryMock: WalletRepositoryMock
    let sut: InitializeWalletUseCase
    
    init() {
        walletRepositoryMock = WalletRepositoryMock()
        sut = InitializeWalletUseCase(walletRepository: walletRepositoryMock)
    }
    
    // MARK: - Execute Tests
    
    @Test("Execute returns alreadyInitialized when wallet exists")
    func executeReturnsAlreadyInitializedWhenWalletExists() async {
        // Given
        walletRepositoryMock.hasWalletResult = true
        
        // When
        let result = await sut.execute()
        
        // Then
        #expect(result == .alreadyInitialized)
        #expect(walletRepositoryMock.hasWalletCallCount == 1)
        #expect(walletRepositoryMock.initializeWalletCallCount == 0)
    }
    
    @Test("Execute returns success when wallet initialization succeeds")
    func executeReturnsSuccessWhenWalletInitializationSucceeds() async {
        // Given
        walletRepositoryMock.hasWalletResult = false
        walletRepositoryMock.initializeWalletResult = true
        
        // When
        let result = await sut.execute()
        
        // Then
        #expect(result == .success)
        #expect(walletRepositoryMock.hasWalletCallCount == 1)
        #expect(walletRepositoryMock.initializeWalletCallCount == 1)
    }
    
    @Test("Execute attempts to create new wallet when initialization fails")
    func executeAttemptsToCreateNewWalletWhenInitializationFails() async {
        // Given
        walletRepositoryMock.hasWalletResult = false
        walletRepositoryMock.initializeWalletResult = false
        walletRepositoryMock.createNewWalletResult = true
        
        // When
        let result = await sut.execute()
        
        // Then
        #expect(result == .success)
        #expect(walletRepositoryMock.hasWalletCallCount == 1)
        #expect(walletRepositoryMock.initializeWalletCallCount == 1)
        #expect(walletRepositoryMock.createNewWalletCallCount == 1)
    }
    
    @Test("Execute returns needsRecovery when both initialization and creation fail")
    func executeReturnsNeedsRecoveryWhenBothInitializationAndCreationFail() async {
        // Given
        walletRepositoryMock.hasWalletResult = false
        walletRepositoryMock.initializeWalletResult = false
        walletRepositoryMock.createNewWalletResult = false
        
        // When
        let result = await sut.execute()
        
        // Then
        #expect(result == .needsRecovery)
        #expect(walletRepositoryMock.hasWalletCallCount == 1)
        #expect(walletRepositoryMock.initializeWalletCallCount == 1)
        #expect(walletRepositoryMock.createNewWalletCallCount == 1)
    }
    
    // MARK: - Create New Wallet Tests
    
    @Test("CreateNewWallet returns true when successful")
    func createNewWalletReturnsTrueWhenSuccessful() async {
        // Given
        walletRepositoryMock.createNewWalletResult = true
        
        // When
        let result = await sut.createNewWallet()
        
        // Then
        #expect(result == true)
        #expect(walletRepositoryMock.createNewWalletCallCount == 1)
    }
    
    @Test("CreateNewWallet returns false when unsuccessful")
    func createNewWalletReturnsFalseWhenUnsuccessful() async {
        // Given
        walletRepositoryMock.createNewWalletResult = false
        
        // When
        let result = await sut.createNewWallet()
        
        // Then
        #expect(result == false)
        #expect(walletRepositoryMock.createNewWalletCallCount == 1)
    }
    
    // MARK: - Check Wallet Status Tests
    
    @Test("CheckWalletStatus returns true when wallet exists")
    func checkWalletStatusReturnsTrueWhenWalletExists() {
        // Given
        walletRepositoryMock.hasWalletResult = true
        
        // When
        let result = sut.checkWalletStatus()
        
        // Then
        #expect(result == true)
        #expect(walletRepositoryMock.hasWalletCallCount == 1)
    }
    
    @Test("CheckWalletStatus returns false when wallet doesn't exist")
    func checkWalletStatusReturnsFalseWhenWalletDoesNotExist() {
        // Given
        walletRepositoryMock.hasWalletResult = false
        
        // When
        let result = sut.checkWalletStatus()
        
        // Then
        #expect(result == false)
        #expect(walletRepositoryMock.hasWalletCallCount == 1)
    }
}