public struct ErrorResponse: Error, Decodable {
    public let message: String
    public let errorCode: String
    public let errorDetails: String
}
