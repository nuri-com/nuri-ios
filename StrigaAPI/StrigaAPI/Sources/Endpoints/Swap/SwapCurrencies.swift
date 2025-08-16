import Foundation

public struct SwapCurrencies: Encodable {
    public let userId: String
    public let sourceAccountId: String
    public let destinationAccountId: String
    public let amount: String
    public let ip: String
    
    public init(userId: String, sourceAccountId: String, destinationAccountId: String, amount: String, ip: String = "127.0.0.1") {
        self.userId = userId
        self.sourceAccountId = sourceAccountId
        self.destinationAccountId = destinationAccountId
        self.amount = amount
        self.ip = ip
    }
}

public struct SwapCurrenciesResponse: Decodable {
    public let id: String
    public let status: String
    public let sourceAccountId: String
    public let destinationAccountId: String
    public let txType: String
    public let order: SwapOrder?
    public let datetime: String
    
    public struct SwapOrder: Decodable {
        public let id: String
        public let price: String
        public let type: String
        public let ticker: String
        public let debit: CurrencyAmount
        public let credit: CurrencyAmount
        
        public struct CurrencyAmount: Decodable {
            public let currency: String
            public let amountFloat: String
            public let amount: String
        }
    }
    
    // Computed properties for backwards compatibility
    public var sourceAmount: String {
        return order?.debit.amount ?? "0"
    }
    
    public var destinationAmount: String {
        return order?.credit.amount ?? "0"
    }
    
    public var exchangeRate: String {
        return order?.price ?? "0"
    }
}