import Foundation
@testable import Nuri

@MainActor
final class AuthenticationServiceMock {
    var isAuthenticated = false
    var authenticateUserCallCount = 0
    var authenticateUserReason: String?
    var authenticateUserResult = true
    var resetAuthenticationCallCount = 0
    
    func authenticateUser(reason: String, completion: @escaping (Bool) -> Void) {
        authenticateUserCallCount += 1
        authenticateUserReason = reason
        completion(authenticateUserResult)
    }
    
    func resetAuthentication() {
        resetAuthenticationCallCount += 1
        isAuthenticated = false
    }
}