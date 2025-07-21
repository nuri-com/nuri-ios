public struct ResendSMS: Encodable {
    public let userID: String

    public init(userID: String) {
        self.userID = userID
    }
}
