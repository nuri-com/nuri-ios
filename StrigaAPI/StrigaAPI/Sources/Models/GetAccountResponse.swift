import Foundation

public struct GetAccountResponse: Decodable {
    public let accountId: String
    public let parentWalletId: String
    public let currency: String
    public let ownerId: String
    public let ownerType: String
    public let createdAt: String
    public let availableBalance: Balance
    public let status: String
    public let blockchainDepositAddress: String?
    public let blockchainNetworks: [BlockchainNetwork]?
    public let linkedCardId: String?
    public let linkedBankAccountId: String?
    public let enriched: AccountEnriched?
    public let transactions: [AccountTransaction]?
    
    public struct Balance: Decodable {
        public let amount: String
        public let currency: String
    }
    
    public struct BlockchainNetwork: Decodable {
        public let network: String
        public let blockchainDepositAddress: String
    }
    
    public struct AccountEnriched: Decodable {
        public let iban: String?
        public let bic: String?
        public let accountHolderName: String?
        
        private enum CodingKeys: String, CodingKey {
            case iban = "IBAN"
            case bic = "BIC"
            case accountHolderName
        }
    }
    
    public struct AccountTransaction: Decodable {
        public let id: String
        public let timestamp: String
        public let accountId: String
        public let amount: String
        public let currency: String
        public let transactionType: String
        public let status: String
        public let blockchainHash: String?
        public let bankingReferenceNumber: String?
        public let memo: String?
        public let exchangeRate: String?
        public let totalFee: String?
    }
}