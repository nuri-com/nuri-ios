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

public struct Account: Codable {
    let id: String
}

public final class StrigaService {

    // MARK: - Dependencies

    private let httpClient = HTTPClient()

    // MARK: - Variables

    public var configuration: StrigaConfiguration?

    // MARK: - Endpoints

    @discardableResult
    public func createUser(_ input: CreateUserInput) async throws -> User {
        return try await httpClient.post(url: "https://api.stripe.com/v1/user/create", input: input)
    }
}
