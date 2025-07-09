import Foundation

public struct AccountStatementResponse: Decodable {
    public let walletId: String
    public let accountId: String
    public let from: String
    public let to: String
    public let transactions: [Transaction]
    public let pageInfo: PageInfo?
}

public struct Transaction: Decodable {
    public let transactionId: String
    public let timestamp: String
    public let type: String
    public let amount: Decimal
    public let currency: String
    public let description: String?
    public let balanceBefore: Decimal?
    public let balanceAfter: Decimal?
}

public struct PageInfo: Decodable {
    public let page: Int
    public let pageSize: Int
    public let totalPages: Int
    public let totalItems: Int
}
