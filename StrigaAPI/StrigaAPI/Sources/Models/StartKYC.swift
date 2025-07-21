public struct StartKYC: Encodable {
    public let userId: String

    public init(userId: String) {
        self.userId = userId
    }
}
