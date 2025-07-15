import Foundation
import CryptoKit

public final class StrigaService {

    // MARK: - Dependencies

    private let httpClient = HTTPClient()

    // MARK: - Variables

    public var configuration: StrigaConfiguration? {
        didSet {
            httpClient.additionalHeaders = [:] // Headers are now generated per request
        }
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
        guard let configuration = configuration else {
            throw NSError(domain: "Striga", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Configuration not set."])
        }
        guard let url = URL(string: configuration.url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "Striga", code: 1001, userInfo: [NSLocalizedDescriptionKey: "URL not set."])
        }
        components.path = path
        guard let url = components.url else {
            throw NSError(domain: "Striga", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Could not construct URL."])
        }
        return url
    }

    private func generateHeaders(for path: String, method: String, query: String = "", body: String? = nil) throws -> [String: String] {
        guard let configuration = configuration else {
            throw NSError(domain: "Striga", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Configuration not set for authentication."])
        }

        let timestamp = String(Int(Date().timeIntervalSince1970))
        var preSign = "\(timestamp)\(method.uppercased())\(path)"
        if !query.isEmpty {
            preSign += "?\(query)"
        }
        if let body = body {
            preSign += body
        }

        let signature = hmacSHA256(data: preSign, key: configuration.secret)

        return [
            "X-API-Key": configuration.key,
            "X-API-Timestamp": timestamp,
            "X-API-Signature": signature,
            "Content-Type": "application/json"
        ]
    }

    private func hmacSHA256(data: String, key: String) -> String {
        let keyData = Data(key.utf8)
        let data = Data(data.utf8)
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(signature).map { String(format: "%02hhx", $0) }.joined()
    }
}
