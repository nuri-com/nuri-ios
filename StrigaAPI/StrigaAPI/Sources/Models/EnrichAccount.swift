import Foundation

public struct EnrichAccount: Codable {
    public let accountId: String
    public let userId: String
    
    public init(accountId: String, userId: String) {
        self.accountId = accountId
        self.userId = userId
    }
}