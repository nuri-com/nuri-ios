import Foundation

public extension StrigaService {
    func getCard(_ input: GetCard) async throws -> GetCardResponse {
        let url = try self.url(for: "v1/cards/get")
        return try await self.httpClient.post(url: url, input: input)
    }
}