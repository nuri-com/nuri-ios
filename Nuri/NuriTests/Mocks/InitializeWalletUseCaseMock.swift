import Foundation
@testable import Nuri

@MainActor
final class InitializeWalletUseCaseMock: InitializeWalletUseCaseType {
    var executeCallCount = 0
    var executeResult: WalletInitializationResult = .success
    var createNewWalletCallCount = 0
    var createNewWalletResult = true
    var checkWalletStatusCallCount = 0
    var checkWalletStatusResult = true
    
    func execute() async -> WalletInitializationResult {
        executeCallCount += 1
        return executeResult
    }
    
    func createNewWallet() async -> Bool {
        createNewWalletCallCount += 1
        return createNewWalletResult
    }
    
    func checkWalletStatus() -> Bool {
        checkWalletStatusCallCount += 1
        return checkWalletStatusResult
    }
}