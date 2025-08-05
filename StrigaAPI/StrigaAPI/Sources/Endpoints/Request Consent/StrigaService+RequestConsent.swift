import Foundation

public extension StrigaService {
    func requestConsent(_ input: RequestConsent) async throws -> RequestConsentResponse {
        let url = try self.url(for: "v1/cards/request-consent")
        return try await self.httpClient.post(url: url, input: input)
    }
}