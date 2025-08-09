import Foundation

public extension StrigaService {
    func startHostedCardSession(_ input: StartHostedCardSession) async throws -> StartHostedCardSessionResponse {
        let url = try self.url(for: "v1/hosted-card/start-session")
        return try await self.httpClient.post(url: url, input: input)
    }
}
