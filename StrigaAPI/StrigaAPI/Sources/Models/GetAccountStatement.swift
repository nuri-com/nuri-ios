public struct GetAccountStatement: Encodable {
    public let userId: String
    public let walletId: String
    public let accountId: String
    public let startDate: Int64
    public let endDate: Int64
    public let page: Int

    public init(userId: String, walletId: String, accountId: String, startDate: Int64, endDate: Int64, page: Int = 1) {
        self.userId = userId
        self.walletId = walletId
        self.accountId = accountId
        self.startDate = startDate
        self.endDate = endDate
        self.page = page
    }
}
