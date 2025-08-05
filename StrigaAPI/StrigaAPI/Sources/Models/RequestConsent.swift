public struct RequestConsent: Encodable {
    public let userId: String
    public let cardId: String
    
    public init(userId: String, cardId: String) {
        self.userId = userId
        self.cardId = cardId
    }
}

public struct RequestConsentResponse: Decodable {
    public let challengeId: String
    public let dateExpires: String
}