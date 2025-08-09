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
    
    public struct Accounts: Codable {
        public let eur: Account?
        public let bnb: Account?
        public let pol: Account?
        public let usdc: Account?
        public let btc: Account?
        public let eth: Account?
        public let usdt: Account?
        
        private enum CodingKeys: String, CodingKey {
            case eur = "EUR"
            case bnb = "BNB"
            case pol = "POL"
            case usdc = "USDC"
            case btc = "BTC"
            case eth = "ETH"
            case usdt = "USDT"
        }
    }
    
    public struct Account: Codable {
        public let accountId: String
        public let parentWalletId: String
        public let currency: String
        public let ownerId: String
        public let ownerType: String
        public let createdAt: String
        public let availableBalance: Balance
        public let linkedCardId: String?
        public let linkedBankAccountId: String?
        public let status: String
        public let permissions: [String]
        public let enriched: Bool
        public let parentApplicationId: String
        public let syncedOwnerId: String
        public let accountPath: String?
        public let blockchainNetworks: [String]?
        public let multiChainSupport: Bool?
        public let bankingDetails: BankingDetails?
    }
    
    public struct Balance: Codable {
        public let amount: String
        public let currency: String
        public let hAmount: String?
        public let fiatEquivalentBalance: String?
        public let fiatCurrency: String?
        public let hFiatEquivalentBalance: String?
        public let rate: String?
    }
    
    public struct BankingDetails: Codable {
        public let iban: String
        public let bic: String
        public let accountHolderName: String
        public let bankCountry: String?
        public let bankName: String?
        
        private enum CodingKeys: String, CodingKey {
            case iban = "IBAN"
            case bic = "BIC"
            case accountHolderName
            case bankCountry
            case bankName
        }
    }
}