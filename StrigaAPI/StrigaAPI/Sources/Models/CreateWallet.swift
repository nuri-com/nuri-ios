public struct CreateWallet: Encodable {
    public let userId: String
    public let currency: String?

    public init(userId: String, currency: String? = nil) {
        self.userId = userId
        self.currency = currency
    }
}
