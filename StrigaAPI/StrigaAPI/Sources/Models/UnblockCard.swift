public struct UnblockCard: Codable {
    public let cardId: String

    public init(cardId: String) {
        self.cardId = cardId
    }
}
