import Foundation

public extension StrigaService {
    func getUser(_ input: GetUser) async throws -> GetUserResponse {
        let url = try self.url(for: "v1/user/get")
        return try await self.httpClient.post(url: url, input: input)
    }
}