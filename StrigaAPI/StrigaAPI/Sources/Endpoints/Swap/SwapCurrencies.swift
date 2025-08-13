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
    public let sourceAmount: String
    public let destinationAmount: String
    public let exchangeRate: String
    public let fee: String?
}