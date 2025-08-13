import Foundation

public struct GetWalletsResponse: Codable {
    public let wallets: [Wallet]
    
    public struct Wallet: Codable {
        public let walletId: String
        public let accounts: Accounts
        public let syncedOwnerId: String
        public let ownerType: String
        public let createdAt: String
        public let comment: String?
        public let walletBalance: String
    }
    
    // Use the same types from CreateWalletResponse for consistency
    public typealias Accounts = CreateWalletResponse.Accounts
    public typealias Account = CreateWalletResponse.Account
    public typealias Balance = CreateWalletResponse.Balance
    public typealias BankingDetails = CreateWalletResponse.Account.BankingDetails
}