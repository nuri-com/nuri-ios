public struct BlockCard: Codable {
    public let cardId: String
    public let blockType: String

    public init(cardId: String, blockType: String) {
        self.cardId = cardId
        self.blockType = blockType
    }
}
