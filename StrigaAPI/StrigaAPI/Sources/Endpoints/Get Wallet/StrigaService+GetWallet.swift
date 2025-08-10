import Foundation

public extension StrigaService {
    
    @discardableResult
    func getWallet(_ walletId: String, userId: String) async throws -> CreateWalletResponse {
        let url = try self.url(for: "v1/wallets/get")
        let body = [
            "walletId": walletId,
            "userId": userId
        ]
        return try await self.httpClient.post(url: url, input: body)
    }
}