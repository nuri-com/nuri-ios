import Foundation

public struct GetWallet: Codable {
    public let userId: String
    public let walletId: String
    
    public init(userId: String, walletId: String) {
        self.userId = userId
        self.walletId = walletId
    }
}