import Foundation

public struct GetAccount: Encodable {
    public let userId: String
    public let accountId: String
    
    public init(userId: String, accountId: String) {
        self.userId = userId
        self.accountId = accountId
    }
}