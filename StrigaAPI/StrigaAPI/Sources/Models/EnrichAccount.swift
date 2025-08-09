import Foundation

public struct EnrichAccount: Codable {
    public let accountId: String
    
    public init(accountId: String) {
        self.accountId = accountId
    }
}