import Foundation
@testable import Nuri

@MainActor
final class ExchangeRateRepositoryMock: ExchangeRateRepositoryType {
    var getExchangeRateCallCount = 0
    var getExchangeRateResult: Double?
    var getCachedExchangeRateCallCount = 0
    var getCachedExchangeRateResult: Double?
    var startPeriodicUpdatesCallCount = 0
    var stopPeriodicUpdatesCallCount = 0
    var capturedUpdateHandler: ((Double) -> Void)?
    
    func getExchangeRate(currency: String) async -> Double? {
        getExchangeRateCallCount += 1
        return getExchangeRateResult
    }
    
    func getCachedExchangeRate(currency: String) -> Double? {
        getCachedExchangeRateCallCount += 1
        return getCachedExchangeRateResult
    }
    
    func startPeriodicUpdates(currency: String, interval: TimeInterval, onUpdate: @escaping (Double) -> Void) {
        startPeriodicUpdatesCallCount += 1
        capturedUpdateHandler = onUpdate
    }
    
    func stopPeriodicUpdates() {
        stopPeriodicUpdatesCallCount += 1
    }
}