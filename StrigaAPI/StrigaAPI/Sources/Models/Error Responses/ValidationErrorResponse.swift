public struct ValidationErrorResponse: Error, Decodable {
    public let message: String
    public let errorCode: String
    public let errorDetails: [InvalidField]

    public struct InvalidField: Decodable {
        public let msg: String
        public let param: String
        public let location: String
    }
}
