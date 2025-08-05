public struct ConfirmConsent: Encodable {
    public let userId: String
    public let challengeId: String
    public let verificationCode: String
    
    public init(userId: String, challengeId: String, verificationCode: String) {
        self.userId = userId
        self.challengeId = challengeId
        self.verificationCode = verificationCode
    }
}

public struct ConfirmConsentResponse: Decodable {
    public let cardAuthToken: String
}