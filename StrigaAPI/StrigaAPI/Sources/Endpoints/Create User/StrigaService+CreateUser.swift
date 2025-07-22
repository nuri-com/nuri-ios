public extension StrigaService {

    @discardableResult
    func createUser(_ input: CreateUser) async throws -> CreateUserResponse {
        let url = try self.url(for: "v1/user/create")
        return try await self.httpClient.post(url: url, input: input)
    }
}
