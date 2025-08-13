import Foundation

/// Manages Blockstream API authentication and token refresh
final class BlockstreamAuthManager {
    static let shared = BlockstreamAuthManager()
    
    // MARK: - Configuration
    private let clientID = "94244a71-10f8-4405-a9e1-f78c7d700ccb"
    private let clientSecret = "mnc6eh2KzGnWrrmUCn0fabEt8OxipVdf"
    private let tokenEndpoint = "https://login.blockstream.com/realms/blockstream-public/protocol/openid-connect/token"
    private let apiBaseURL = "https://enterprise.blockstream.info/api"
    
    // MARK: - Token Management
    private var accessToken: String?
    private var tokenExpiryTime: Date?
    private let tokenLifetime: TimeInterval = 300 // 5 minutes
    private let tokenRefreshBuffer: TimeInterval = 30 // Refresh 30 seconds before expiry
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get the authenticated API base URL
    var authenticatedBaseURL: String {
        return apiBaseURL
    }
    
    /// Get current access token, refreshing if needed
    func getAccessToken() async throws -> String {
        // Check if we have a valid token
        if let token = accessToken,
           let expiry = tokenExpiryTime,
           Date() < expiry.addingTimeInterval(-tokenRefreshBuffer) {
            print("🔑 [BlockstreamAuth] Using cached token (expires in \(expiry.timeIntervalSince(Date()))s)")
            return token
        }
        
        // Need to refresh token
        print("🔑 [BlockstreamAuth] Refreshing access token...")
        return try await refreshToken()
    }
    
    /// Get authorization header value
    func getAuthorizationHeader() async throws -> String {
        let token = try await getAccessToken()
        return "Bearer \(token)"
    }
    
    // MARK: - Private Methods
    
    private func refreshToken() async throws -> String {
        print("🔄 [BlockstreamAuth] Requesting new access token...")
        
        guard let url = URL(string: tokenEndpoint) else {
            throw BlockstreamAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create request body
        let bodyParams = [
            "grant_type": "client_credentials",
            "client_id": clientID,
            "client_secret": clientSecret,
            "scope": "openid"
        ]
        
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BlockstreamAuthError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [BlockstreamAuth] Token request failed with status: \(httpResponse.statusCode)")
                throw BlockstreamAuthError.tokenRequestFailed(statusCode: httpResponse.statusCode)
            }
            
            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else {
                throw BlockstreamAuthError.invalidTokenResponse
            }
            
            // Store token and expiry time
            self.accessToken = token
            self.tokenExpiryTime = Date().addingTimeInterval(tokenLifetime)
            
            print("✅ [BlockstreamAuth] Access token obtained, expires at \(tokenExpiryTime!)")
            return token
            
        } catch {
            print("❌ [BlockstreamAuth] Failed to refresh token: \(error)")
            throw error
        }
    }
}

// MARK: - Error Types

enum BlockstreamAuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case tokenRequestFailed(statusCode: Int)
    case invalidTokenResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid token endpoint URL"
        case .invalidResponse:
            return "Invalid response from token endpoint"
        case .tokenRequestFailed(let statusCode):
            return "Token request failed with status code: \(statusCode)"
        case .invalidTokenResponse:
            return "Invalid token response format"
        }
    }
}