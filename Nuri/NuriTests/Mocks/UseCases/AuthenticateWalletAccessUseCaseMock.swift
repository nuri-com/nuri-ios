import Foundation
@testable import Nuri

@MainActor
final class AuthenticateWalletAccessUseCaseMock: AuthenticateWalletAccessUseCaseType {
    var executeCallCount = 0
    var executeResult = true
    var executeReason: String?
    var isAuthenticatedCallCount = 0
    var isAuthenticatedResult = false
    var resetAuthenticationCallCount = 0
    
    func execute(reason: String) async -> Bool {
        executeCallCount += 1
        executeReason = reason
        return executeResult
    }
    
    func isAuthenticated() -> Bool {
        isAuthenticatedCallCount += 1
        return isAuthenticatedResult
    }
    
    func resetAuthentication() {
        resetAuthenticationCallCount += 1
    }
}