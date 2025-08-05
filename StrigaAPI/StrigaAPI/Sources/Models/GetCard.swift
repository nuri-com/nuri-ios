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
    public let expiryMonth: String
    public let expiryYear: String
    public let cvv: String?
    public let cardNumber: String?
    public let status: String
    public let linkedAccountId: String
    public let parentWalletId: String
    public let createdAt: String
}