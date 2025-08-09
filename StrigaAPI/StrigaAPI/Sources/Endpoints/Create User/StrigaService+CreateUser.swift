public extension StrigaService {

    @discardableResult
    func createUser(_ input: CreateUser) async throws -> CreateUserResponse {
        let url = try self.url(for: "v1/user/create")
        
        // Debug logging to verify what we're sending to Striga
        print("[Striga API] Creating user with:")
        print("  - firstName: \(input.firstName)")
        print("  - lastName: \(input.lastName)")
        print("  - email: \(input.email)")
        print("  - mobile: \(input.mobile.countryCode) \(input.mobile.number)")
        
        // AGGRESSIVE LOGGING
        print("[GEMINI] StrigaService+CreateUser.swift: createUser called with input: \(input)")

        return try await self.httpClient.post(url: url, input: input)
    }
}
