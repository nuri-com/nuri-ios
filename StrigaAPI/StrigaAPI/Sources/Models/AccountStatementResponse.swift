import Foundation

public struct AccountStatementResponse: Decodable {
    public let walletId: String?
    public let accountId: String?
    public let startDate: String?
    public let endDate: String?
    public let transactions: [StrigaAccountTransaction]
    public let count: Int?
    public let total: Int?
    
    // Handle both field names
    private enum CodingKeys: String, CodingKey {
        case walletId
        case accountId
        case startDate
        case endDate
        case transactions
        case count
        case total
    }
}

// Keep Transaction as a type alias for backward compatibility
public typealias Transaction = StrigaAccountTransaction
