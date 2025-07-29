public struct VerifyMobile: Encodable {
    public let userId: String
    public let verificationCode: String

    public init(userId: String, verificationCode: String) {
        self.userId = userId
        self.verificationCode = verificationCode
    }
}
