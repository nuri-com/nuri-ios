import Foundation
@testable import Nuri

@MainActor
final class GetExchangeRateUseCaseMock: GetExchangeRateUseCaseType {
    var executeCallCount = 0
    var executeResult: Double = 50000.0
    var getCachedResult: Double = 45000.0
    var startPeriodicUpdatesCalled = false
    var stopPeriodicUpdatesCalled = false
    
    func execute(currency: String) async -> Double {
        executeCallCount += 1
        return executeResult
    }
    
    func getCached(currency: String) -> Double {
        return getCachedResult
    }

    var startPeriodicUpdatesCallbacks: [(Double) -> Void] = []
    func startPeriodicUpdates(currency: String, interval: TimeInterval, onUpdate: @escaping (Double) -> Void) {
        startPeriodicUpdatesCalled = true
        // Optionally call the update handler with test data
        startPeriodicUpdatesCallbacks.append(onUpdate)
    }
    
    func stopPeriodicUpdates() {
        stopPeriodicUpdatesCalled = true
    }
}
