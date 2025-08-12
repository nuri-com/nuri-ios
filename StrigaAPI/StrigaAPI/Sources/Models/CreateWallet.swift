public struct CreateWallet: Encodable {
    public let userId: String
    public let accountCurrency: [String]?

    public init(userId: String, accountCurrency: [String]? = nil) {
        self.userId = userId
        self.accountCurrency = accountCurrency
    }
}
