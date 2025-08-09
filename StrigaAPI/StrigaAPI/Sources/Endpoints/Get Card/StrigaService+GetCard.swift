import Foundation

public extension StrigaService {
    func getCard(_ input: GetCard) async throws -> GetCardResponse {
        // Build URL with card ID as path parameter
        let path = "v1/card/\(input.cardId)"
        let url = try self.url(for: path)
        
        // For GET request with auth token, we need to pass it as query parameter
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem]()
        
        if let authToken = input.authToken {
            queryItems.append(URLQueryItem(name: "authToken", value: authToken))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let finalURL = components.url else {
            throw NSError(domain: "StrigaAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"])
        }
        
        return try await self.httpClient.get(url: finalURL)
    }
}