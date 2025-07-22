import Foundation

public final class StrigaService {

    // MARK: - Dependencies

    internal let httpClient = HTTPClient()

    // MARK: - Public

    public var configuration: StrigaConfiguration?
    public static let shared = StrigaService()

    // MARK: - Initialization

    private init() {
        httpClient.delegate = self
    }

    // MARK: - Endpoints

    @discardableResult
    public func verifyMobile(_ input: VerifyMobile) async throws -> EmptyResponse {
        let url = try url(for: "v1/user/verify-mobile")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func verifyEmail(_ input: VerifyEmail) async throws -> EmptyResponse {
        let url = try url(for: "v1/user/verify-email")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func resendSMS(_ input: ResendSMS) async throws -> EmptyResponse {
        let url = try url(for: "v1/user/resend-sms")
        return try await httpClient.post(url: url, input: input)
    }

    @discardableResult
    public func startKYC(_ input: StartKYC) async throws -> StartKYCResponse {
        let url = try url(for: "v0/user/kyc/start")
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
    public func createWallet(_ input: CreateWallet) async throws -> CreateWalletResponse {
        let url = try url(for: "v1/wallets/create")
        return try await httpClient.post(url: url, input: input)
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

    internal func url(for path: String) throws -> URL {
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

    func headers(for request: URLRequest, body: Data?) -> [String : String] {
        do {
            guard let configuration else {
                throw NSError(domain: "Striga", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Configuration not set."])
            }
            let signatureProvider = SignatureProvider(configuration: configuration)
            let headers = try signatureProvider.headers(for: request, body: body)
            print("[Striga] headers: \(headers)")
            return headers
        } catch {
            print("[Striga] Signature: Error generating headers: \(error)")
            return [:]
        }
    }
}
