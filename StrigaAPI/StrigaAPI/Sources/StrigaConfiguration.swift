public struct StrigaConfiguration: Equatable {
    public var url: String
    public var key: String
    public var secret: String
    public var uiSecret: String?
    public var applicationId: String?

    public init(url: String, key: String, secret: String, uiSecret: String? = nil, applicationId: String? = nil) {
        self.url = url
        self.key = key
        self.secret = secret
        self.uiSecret = uiSecret
        self.applicationId = applicationId
    }
}
