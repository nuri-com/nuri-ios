import Foundation

public struct StrigaAccountTransaction: Decodable {
    public let id: String
    public let accountId: String
    public let timestamp: String
    public let txType: String
    public let txSubType: String?
    public let memo: String?
    public let currency: String
    public let exchangeRate: String?
    public let debit: String?
    public let credit: String?
    public let balanceBefore: Balance?
    public let balanceAfter: Balance?
    
    // Card-specific fields
    public let relatedCardTransactionId: String?
    public let isCardAuthorizationHold: Bool?
    public let relatedCardId: String?
    public let relatedCardSettlementId: String?
    public let cardTransactionAmount: String?
    public let cardTransactionCurrency: String?
    
    // Banking-specific fields
    public let bankingTransactionId: String?
    public let bankingTransactionShortId: String?
    public let bankingTransactionAmount: String?
    public let bankingSenderBic: String?
    public let bankingSenderIban: String?
    public let bankingSenderName: String?
    public let bankingPaymentType: String?
    
    // Blockchain-specific fields
    public let blockchainSourceAddress: String?
    public let txHash: String?
    public let blockchainDepositAddress: String?
    public let blockchainConfirmations: Int?
    public let blockchainTransactionAmount: String?
    public let blockchainNetwork: String?
    
    // Exchange-specific fields
    public let order: Order?
    
    public struct Balance: Decodable {
        public let amount: String
        public let balance: String
        public let currency: String
    }
    
    public struct Order: Decodable {
        public let price: String?
        public let debit: OrderAmount?
        public let credit: OrderAmount?
    }
    
    public struct OrderAmount: Decodable {
        public let currency: String
        public let amountFloat: String
        public let amount: String
    }
    
    // Computed property to get the transaction amount
    public var amount: String {
        // Return debit as negative, credit as positive
        if let debit = debit {
            return "-\(debit)"
        } else if let credit = credit {
            return credit
        }
        return "0"
    }
    
    // Computed property for transaction type (for compatibility)
    public var transactionType: String {
        return txType
    }
    
    // Computed property for status
    public var status: String {
        return "COMPLETED"
    }
    
    // Computed property for blockchain hash
    public var blockchainHash: String? {
        return txHash
    }
    
    public var bankingReferenceNumber: String? {
        return bankingTransactionId
    }
}