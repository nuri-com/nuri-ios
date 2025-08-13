import Foundation

public extension StrigaService {
    func getUser(_ input: GetUser) async throws -> GetUserResponse {
        // Try the plural form like wallets endpoint
        // If this doesn't work, we may need to use v1/users/{userId} with GET
        let url = try self.url(for: "v1/users/get")
        return try await self.httpClient.post(url: url, input: input)
    }
}