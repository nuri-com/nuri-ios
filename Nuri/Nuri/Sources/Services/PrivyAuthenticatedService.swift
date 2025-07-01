import Foundation

// Add HTTPMethod enum
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

/// Service for authenticated API calls using stored Privy tokens
enum PrivyAuthenticatedService {
    
    /// Common method for making authenticated requests to Privy API
    static func makeRequest(
        endpoint: String,
        method: HTTPMethod,
        body: [String: Any]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let tokens = PasskeyService.getStoredTokens()
        guard let accessToken = tokens.0 else {
            print("❌ [PrivyAuthenticatedService] No access token found")
            completion(.failure(NSError(domain: "PrivyAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token found"])))
            return
        }
        
        let urlString = "https://auth.privy.io/api/v1/\(endpoint)"
        guard let url = URL(string: urlString) else {
            print("❌ [PrivyAuthenticatedService] Invalid URL: \(urlString)")
            completion(.failure(NSError(domain: "PrivyAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("🌐 [PrivyAuthenticatedService] Making \(method.rawValue) request to: \(endpoint)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(PrivyManager.appId, forHTTPHeaderField: "privy-app-id")
        request.setValue(PrivyManager.clientId, forHTTPHeaderField: "privy-client-id")
        
        // Add the native app identifier header (CRITICAL for native mobile apps)
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "x-native-app-identifier")
            print("   📱 Native app ID: \(bundleId)")
        } else {
            print("   ⚠️ Warning: Could not get bundle identifier")
        }
        
        // Log headers for debugging
        print("   📤 Headers:")
        print("      Authorization: Bearer \(accessToken.prefix(20))...")
        print("      privy-app-id: \(PrivyManager.appId)")
        print("      privy-client-id: \(PrivyManager.clientId)")
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            if let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("   📤 Body: \(bodyString)")
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("   📥 Response status: \(httpResponse.statusCode)")
                
                // Log response headers for debugging
                if httpResponse.statusCode >= 400 {
                    print("   ⚠️ Error response headers:")
                    for (key, value) in httpResponse.allHeaderFields {
                        print("      \(key): \(value)")
                    }
                }
            }
            
            if let error = error {
                print("   ❌ Network error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("   ❌ No data in response")
                completion(.failure(NSError(domain: "PrivyAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data in response"])))
                return
            }
            
            if let raw = String(data: data, encoding: .utf8) {
                print("   📥 Raw response: \(raw)")
            }
            
            // Try to parse JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for error in response
                    if let error = json["error"] as? String {
                        print("   ❌ API error: \(error)")
                        completion(.failure(NSError(domain: "PrivyAuth", code: -3, userInfo: [
                            NSLocalizedDescriptionKey: error,
                            "data": data
                        ])))
                        return
                    }
                    
                    completion(.success(json))
                } else {
                    print("   ❌ Response is not a dictionary")
                    completion(.failure(NSError(domain: "PrivyAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                print("   ❌ JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Gets the current user data using stored access token
    static func getCurrentUser(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        makeRequest(endpoint: "users/me", method: .GET, completion: completion)
    }
    
    /// Links a new passkey to the current user account
    static func linkPasskey(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let tokens = PasskeyService.getStoredTokens()
        guard let accessToken = tokens.0 else {
            completion(.failure(NSError(domain: "PrivyAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token found"])))
            return
        }
        
        // This endpoint would be specific to Privy's passkey linking flow
        // You'd need to check their API documentation for the exact endpoint
        let url = URL(string: "https://auth.privy.io/api/v1/passwordless/link/init")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(PrivyManager.appId, forHTTPHeaderField: "privy-app-id")
        request.setValue(PrivyManager.clientId, forHTTPHeaderField: "privy-client-id")
        
        let body = ["type": "passkey"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "PrivyAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            completion(.success(json))
        }.resume()
    }
    
    /// Refreshes the access token using the refresh token
    static func refreshAccessToken(completion: @escaping (Result<String, Error>) -> Void) {
        let tokens = PasskeyService.getStoredTokens()
        guard let refreshToken = tokens.1 else {
            completion(.failure(NSError(domain: "PrivyAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No refresh token found"])))
            return
        }
        
        let url = URL(string: "https://auth.privy.io/api/v1/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(PrivyManager.appId, forHTTPHeaderField: "privy-app-id")
        request.setValue(PrivyManager.clientId, forHTTPHeaderField: "privy-client-id")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newToken = json["token"] as? String else {
                completion(.failure(NSError(domain: "PrivyAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid refresh response"])))
                return
            }
            
            // Store the new token
            PasskeyService.storeAuthTokens(accessToken: newToken, refreshToken: refreshToken, userId: tokens.2)
            completion(.success(newToken))
        }.resume()
    }
    
    /// Creates an embedded wallet using stored access token
    static func createEmbeddedWallet(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        print("🔨 [PrivyAuthenticatedService] Creating embedded wallet...")
        
        // Try the correct wallet creation endpoint without the 'type' parameter
        makeRequest(
            endpoint: "wallets",
            method: .POST,
            body: [
                "chain_type": "ethereum"
            ],
            completion: { result in
                switch result {
                case .success(let data):
                    print("✅ [PrivyAuthenticatedService] Wallet created successfully")
                    completion(.success(data))
                case .failure(let error):
                    print("⚠️ [PrivyAuthenticatedService] Wallet creation failed, checking if user already has wallets...")
                    
                    // If wallet creation fails, it might be because user already has one
                    // But to avoid rate limiting, we'll return the error instead of checking again
                    print("❌ [PrivyAuthenticatedService] Wallet creation failed: \(error)")
                    completion(.failure(error))
                }
            }
        )
    }
    
    /// Signs a message using the embedded wallet (requires additional implementation)
    static func signMessage(message: String, walletAddress: String, completion: @escaping (Result<String, Error>) -> Void) {
        // This would require implementing the MPC signing flow
        // which is complex and requires multiple API calls
        completion(.failure(NSError(domain: "PrivyAuth", code: -99, userInfo: [NSLocalizedDescriptionKey: "Signing not yet implemented - requires MPC flow"])))
    }
}

extension PrivyAuthenticatedService {
    static func createUserWallets(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        makeRequest(
            endpoint: "users/me/wallets",
            method: .POST,
            body: [
                "chain_type": "ethereum",
                "wallet_index": 0
            ],
            completion: completion
        )
    }
} 