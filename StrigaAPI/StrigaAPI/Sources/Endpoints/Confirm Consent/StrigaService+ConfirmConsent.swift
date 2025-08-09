import Foundation

public extension StrigaService {
    func confirmConsent(_ input: ConfirmConsent) async throws -> ConfirmConsentResponse {
        let url = try self.url(for: "v1/card/confirm-consent")
        return try await self.httpClient.post(url: url, input: input)
    }
}