import Foundation

public final class StrigaService {

    // MARK: - Dependencies

    private let httpClient = HTTPClient()

    // MARK: - Public

    public var configuration: StrigaConfiguration?
    public static let shared = StrigaService()

    // MARK: - Initialization

    private init() {
        httpClient.delegate = self
    }

    // MARK: - Endpoints

    @discardableResult
    public func createUser(_ input: CreateUser) async throws -> CreateUserResponse {
        let url = try url(for: "v1/user/create")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func createCard(_ input: CreateCard) async throws -> CreateCardResponse {
        let url = try url(for: "v1/card/create")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func card(_ id: String) async throws -> CardResponse {
        let url = try url(for: "v1/card/\(id)")
        return try await httpClient.get(url: url)
    }

    @discardableResult
    public func blockCard(_ input: BlockCard) async throws -> EmptyResponse {
        let url = try url(for: "v1/card/block")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func blockCard(_ input: UnblockCard) async throws -> EmptyResponse {
        let url = try url(for: "v1/card/unblock")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func accountStatements(_ input: GetAccountStatement) async throws -> AccountStatementResponse {
        let url = try url(for: "v1/wallets/get/account/statement")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func initiateBankTransfer(_ input: InitiateBankTransfer) async throws -> InitiateBankTransferResponse {
        let url = try url(for: "v1/wallets/send/initiate/bank")
        return try await httpClient.post(url: url, input: input)
    }

    // MARK: - Private

    private func url(for path: String) throws -> URL {
        guard let configuration else {
            throw NSError(domain: "Striga", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Configuration not set."])
        }
        guard let url = URL(string: configuration.url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "Striga", code: 1002, userInfo: [NSLocalizedDescriptionKey: "URL not set."])
        }
        components.path += path
        guard let url = components.url else {
            throw NSError(domain: "Striga", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Could not construct URL. \(components)"])
        }
        return url
    }
}

extension StrigaService: HTTPClientDelegate {

    func headers<E: Encodable>(for request: URLRequest, body: E?) -> [String : String] {
        do {
            guard let configuration else {
                throw NSError(domain: "Striga", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Configuration not set."])
            }
            let signatureProvider = StrigaSignatureProvider(configuration: configuration)
            let headers = try signatureProvider.headers(for: request, body: body)
            print("[Striga] headers: \(headers)")
            return headers
        } catch {
            print("[Striga] Signature: Error generating headers: \(error)")
            return [:]
        }
    }
}
