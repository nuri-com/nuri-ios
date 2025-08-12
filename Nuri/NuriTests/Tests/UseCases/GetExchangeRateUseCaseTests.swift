import Testing
@testable import Nuri

@MainActor
struct GetExchangeRateUseCaseTests {
    
    let repositoryMock: ExchangeRateRepositoryMock
    let sut: GetExchangeRateUseCase
    
    init() {
        repositoryMock = ExchangeRateRepositoryMock()
        sut = GetExchangeRateUseCase(repository: repositoryMock)
    }
    
    // MARK: - Execute Tests
    
    @Test("Execute returns fresh rate when available")
    func executeReturnsFreshRateWhenAvailable() async {
        // Given
        repositoryMock.getExchangeRateResult = 55000.0
        
        // When
        let result = await sut.execute(currency: "EUR")
        
        // Then
        #expect(result == 55000.0)
        #expect(repositoryMock.getExchangeRateCallCount == 1)
    }
    
    @Test("Execute falls back to cached rate when fresh rate unavailable")
    func executeFallsBackToCachedRateWhenFreshRateUnavailable() async {
        // Given
        repositoryMock.getExchangeRateResult = nil
        repositoryMock.getCachedExchangeRateResult = 45000.0
        
        // When
        let result = await sut.execute(currency: "EUR")
        
        // Then
        #expect(result == 45000.0)
        #expect(repositoryMock.getExchangeRateCallCount == 1)
        #expect(repositoryMock.getCachedExchangeRateCallCount == 1)
    }
    
    @Test("Execute returns zero when no rate available")
    func executeReturnsZeroWhenNoRateAvailable() async {
        // Given
        repositoryMock.getExchangeRateResult = nil
        repositoryMock.getCachedExchangeRateResult = nil
        
        // When
        let result = await sut.execute(currency: "EUR")
        
        // Then
        #expect(result == 0.0)
        #expect(repositoryMock.getExchangeRateCallCount == 1)
        #expect(repositoryMock.getCachedExchangeRateCallCount == 1)
    }
    
    // MARK: - Get Cached Tests
    
    @Test("GetCached returns cached rate when available")
    func getCachedReturnsCachedRateWhenAvailable() {
        // Given
        repositoryMock.getCachedExchangeRateResult = 48000.0
        
        // When
        let result = sut.getCached(currency: "EUR")
        
        // Then
        #expect(result == 48000.0)
        #expect(repositoryMock.getCachedExchangeRateCallCount == 1)
    }
    
    @Test("GetCached returns zero when no cached rate")
    func getCachedReturnsZeroWhenNoCachedRate() {
        // Given
        repositoryMock.getCachedExchangeRateResult = nil
        
        // When
        let result = sut.getCached(currency: "USD")
        
        // Then
        #expect(result == 0.0)
        #expect(repositoryMock.getCachedExchangeRateCallCount == 1)
    }
    
    // MARK: - Periodic Updates Tests
    
    @Test("StartPeriodicUpdates delegates to repository")
    func startPeriodicUpdatesDelegatesToRepository() {
        // Given
        var capturedRate: Double?
        let updateHandler: (Double) -> Void = { rate in
            capturedRate = rate
        }
        
        // When
        sut.startPeriodicUpdates(currency: "EUR", interval: 60, onUpdate: updateHandler)
        
        // Then
        #expect(repositoryMock.startPeriodicUpdatesCallCount == 1)
        
        // Simulate an update from repository
        repositoryMock.capturedUpdateHandler?(52000.0)
        #expect(capturedRate == 52000.0)
    }
    
    @Test("StopPeriodicUpdates delegates to repository")
    func stopPeriodicUpdatesDelegatesToRepository() {
        // When
        sut.stopPeriodicUpdates()
        
        // Then
        #expect(repositoryMock.stopPeriodicUpdatesCallCount == 1)
    }
}