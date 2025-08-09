public struct RequestConsent: Encodable {
    public let userId: String
    public let cardId: String
    public let channel: String?
    
    public init(userId: String, cardId: String, channel: String? = nil) {
        self.userId = userId
        self.cardId = cardId
        self.channel = channel
    }
}

public struct RequestConsentResponse: Decodable {
    public let challengeId: String
    public let dateExpires: String
}