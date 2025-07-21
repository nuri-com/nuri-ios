public struct StartKYCResponse: Decodable {
    public let provider: String
    public let token: String
    public let userId: String
    public let verificationLink: String
}
