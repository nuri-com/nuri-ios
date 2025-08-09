import Foundation

public extension StrigaService {
    
    @discardableResult
    func getWallet(_ walletId: String) async throws -> CreateWalletResponse {
        let url = try self.url(for: "v1/wallets/get/\(walletId)")
        return try await self.httpClient.get(url: url)
    }
    
    // Get all wallets for a user
    @discardableResult
    func getAllUserWallets(_ userId: String) async throws -> GetAllWalletsResponse {
        let url = try self.url(for: "v1/wallets/get/all")
        // Add userId as query parameter
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "userId", value: userId)]
        return try await self.httpClient.get(url: components.url!)
    }
}

public struct GetAllWalletsResponse: Decodable {
    public let wallets: [CreateWalletResponse]
}