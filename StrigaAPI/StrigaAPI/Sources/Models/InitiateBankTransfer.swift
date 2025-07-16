public struct InitiateBankTransfer: Codable {
    public let userId: String
    public let sourceAccountId: String
    public let destination: BankDestination
    public let memo: String
    public let amount: String

    public init(userId: String, sourceAccountId: String, destination: BankDestination, memo: String, amount: String) {
        self.userId = userId
        self.sourceAccountId = sourceAccountId
        self.destination = destination
        self.memo = memo
        self.amount = amount
    }

    public struct BankDestination: Codable {
        public let iban: String
        public let bic: String

        public init(iban: String, bic: String) {
            self.iban = iban
            self.bic = bic
        }
    }
}
