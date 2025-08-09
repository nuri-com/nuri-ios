import Foundation

public struct GetWallets: Codable {
    public let userId: String
    
    public init(userId: String) {
        self.userId = userId
    }
}