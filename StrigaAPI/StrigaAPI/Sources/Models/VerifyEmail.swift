public struct VerifyEmail: Encodable {
    public let userId: String
    public let verificationId: String

    public init(userId: String, verificationId: String) {
        self.userId = userId
        self.verificationId = verificationId
    }
}
