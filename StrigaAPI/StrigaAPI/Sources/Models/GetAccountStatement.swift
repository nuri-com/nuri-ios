public struct GetAccountStatement: Encodable {
    public let walletId: String
    public let accountId: String
    public let from: String
    public let to: String

    public init(walletId: String, accountId: String, from: String, to: String) {
        self.walletId = walletId
        self.accountId = accountId
        self.from = from
        self.to = to
    }
}
