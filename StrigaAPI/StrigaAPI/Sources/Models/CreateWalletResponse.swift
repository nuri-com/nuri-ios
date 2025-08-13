import Foundation

public struct CreateWalletResponse: Codable {
    public let walletId: String
    public let accounts: Accounts
    public let syncedOwnerId: String
    public let ownerType: OwnerType
    public let createdAt: String
    public let comment: String
    public let walletBalance: String

    public struct Accounts: Codable {
        public let eur: Account?
        public let bnb: Account?
        public let pol: Account?
        public let usdc: Account?
        public let btc: Account?
        public let eth: Account?
        public let usdt: Account?
        public let sol: Account?

        private enum CodingKeys: String, CodingKey {
            case eur = "EUR"
            case bnb = "BNB"
            case pol = "POL"
            case usdc = "USDC"
            case btc = "BTC"
            case eth = "ETH"
            case usdt = "USDT"
            case sol = "SOL"
        }
    }

    public struct Account: Codable {
        public let accountId: String
        public let parentWalletId: String
        public let currency: String
        public let ownerId: String
        public let ownerType: OwnerType
        public let createdAt: String
        public let availableBalance: Balance
        public let linkedCardId: String?
        public let linkedBankAccountId: String?
        public let status: Status
        public let permissions: [Permission]
        public let enriched: Bool
        public let parentApplicationId: String
        public let syncedOwnerId: String
        public let accountPath: String
        public let blockchainNetworks: [BlockchainNetworkInfo]?
        public let multiChainSupport: Bool?
        public let blockchainDepositAddress: String?
        public let blockchainNetwork: BlockchainNetworkInfo?
        public let bankingDetails: BankingDetails?
        
        public struct BlockchainNetworkInfo: Codable {
            public let name: String
        }
        
        public struct BankingDetails: Codable {
            public let currency: String
            public let status: String
            public let internalAccountId: String
            public let bankCountry: String
            public let bankAddress: String
            public let iban: String
            public let bic: String
            public let accountNumber: String
            public let bankName: String
            public let bankAccountHolderName: String
            public let provider: String
            public let paymentType: String?
            public let domestic: Bool
            public let routingCodeEntries: [String]
            public let payInReference: String?
            public let bban: String?
            
            // Computed property for compatibility
            public var accountHolderName: String {
                return bankAccountHolderName
            }
        }
    }

    public struct Balance: Codable {
        public let amount: String
        public let currency: String
        public let hAmount: String
        public let fiatEquivalentBalance: String
        public let fiatCurrency: String
        public let hFiatEquivalentBalance: String
        public let rate: String
    }

    public enum OwnerType: String, Codable {
        case consumer = "CONSUMER"
        case business = "BUSINESS"
    }

    public enum Status: String, Codable {
        case active = "ACTIVE"
        case blocked = "BLOCKED"
        case closed = "CLOSED"
    }

    public enum Permission: String, Codable {
        case custody = "CUSTODY"
        case trade = "TRADE"
        case `inter` = "INTER"
        case `intra` = "INTRA"
    }
}
