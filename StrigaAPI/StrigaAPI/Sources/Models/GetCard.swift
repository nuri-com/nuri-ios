import Foundation

public struct GetCard: Encodable {
    public let userId: String
    public let cardId: String
    public let authToken: String?
    
    public init(userId: String, cardId: String, authToken: String? = nil) {
        self.userId = userId
        self.cardId = cardId
        self.authToken = authToken
    }
}

public struct GetCardResponse: Decodable {
    public let name: String
    public let id: String
    public let type: String
    public let userId: String
    public let maskedCardNumber: String
    public let expiryData: String  // Changed from expiryMonth/Year - API returns "2027-07-31T23:59:59Z"
    public let cvv: String?
    public let cardNumber: String?
    public let status: String
    public let linkedAccountId: String
    public let parentWalletId: String
    public let createdAt: String
    
    // Computed properties to extract month/year from expiryData
    public var expiryMonth: Int {
        // Parse "2027-07-31T23:59:59Z" to get month
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: expiryData) {
            let calendar = Calendar.current
            return calendar.component(.month, from: date)
        }
        return 1  // Default January if parsing fails
    }
    
    public var expiryYear: Int {
        // Parse "2027-07-31T23:59:59Z" to get year
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: expiryData) {
            let calendar = Calendar.current
            return calendar.component(.year, from: date)
        }
        return 2027  // Default if parsing fails
    }
}