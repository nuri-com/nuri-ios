import Foundation

protocol GetExchangeRateUseCaseType {
    func execute(currency: String) async -> Double
    func getCached(currency: String) -> Double
    func startPeriodicUpdates(currency: String, interval: TimeInterval, onUpdate: @escaping (Double) -> Void)
    func stopPeriodicUpdates()
}

final class GetExchangeRateUseCase: GetExchangeRateUseCaseType {
    
    // MARK: - Dependencies
    
    private let repository: ExchangeRateRepositoryType
    
    // MARK: - Initialization
    
    init(repository: ExchangeRateRepositoryType = ExchangeRateRepository()) {
        self.repository = repository
    }
    
    // MARK: - Public Methods
    
    func execute(currency: String) async -> Double {
        // Try to get fresh rate
        if let freshRate = await repository.getExchangeRate(currency: currency) {
            return freshRate
        }
        
        // Fall back to cached rate
        if let cachedRate = repository.getCachedExchangeRate(currency: currency) {
            print("⚠️ [GetExchangeRateUseCase] Using cached rate as fallback")
            return cachedRate
        }
        
        // Return 0 if no rate available
        print("❌ [GetExchangeRateUseCase] No exchange rate available")
        return 0.0
    }
    
    func getCached(currency: String) -> Double {
        return repository.getCachedExchangeRate(currency: currency) ?? 0.0
    }
    
    func startPeriodicUpdates(currency: String, interval: TimeInterval = 60, onUpdate: @escaping (Double) -> Void) {
        repository.startPeriodicUpdates(currency: currency, interval: interval, onUpdate: onUpdate)
    }
    
    func stopPeriodicUpdates() {
        repository.stopPeriodicUpdates()
    }
}