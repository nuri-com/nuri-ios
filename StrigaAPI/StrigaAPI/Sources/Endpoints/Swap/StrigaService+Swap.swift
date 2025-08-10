import Foundation

public extension StrigaService {
    
    @discardableResult
    func swapCurrencies(_ input: SwapCurrencies) async throws -> SwapCurrenciesResponse {
        let url = try self.url(for: "v1/wallets/swap")
        return try await self.httpClient.post(url: url, input: input)
    }
    
    // Get exchange rate before swapping
    @discardableResult
    func getExchangeRate(from: String, to: String, amount: String) async throws -> ExchangeRateResponse {
        let url = try self.url(for: "v1/trade/rates")
        let body = [
            "from": from,
            "to": to,
            "amount": amount
        ]
        return try await self.httpClient.post(url: url, input: body)
    }
}

public struct ExchangeRateResponse: Decodable {
    public let rate: String
    public let amount: String
    public let fee: String?
}