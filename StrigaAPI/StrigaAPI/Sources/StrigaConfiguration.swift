public struct StrigaConfiguration: Equatable {
    public var url: String
    public var key: String
    public var secret: String

    public init(url: String, key: String, secret: String) {
        self.url = url
        self.key = key
        self.secret = secret
    }
}
