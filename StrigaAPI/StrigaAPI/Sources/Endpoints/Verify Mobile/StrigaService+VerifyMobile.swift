extension StrigaService {

    public func verifyMobile(_ input: VerifyMobile) async throws {
        let url = try url(for: "v1/user/verify-mobile")
        return try await httpClient.post(url: url, input: input)
    }
}
