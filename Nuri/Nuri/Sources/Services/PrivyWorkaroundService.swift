import Foundation

/// Workaround service that provides SDK-like functionality using stored tokens
/// This is necessary because the Privy SDK doesn't support native passkeys yet
public class PrivyWorkaroundService {
    
    /// Shared instance
    static let shared = PrivyWorkaroundService()
    
    private init() {}
    
    /// Check if user is authenticated (has valid tokens)
    var isAuthenticated: Bool {
        let tokens = PasskeyService.getStoredTokens()
        return tokens.0 != nil && tokens.2 != nil
    }
    
    /// Get current user ID
    var currentUserId: String? {
        let tokens = PasskeyService.getStoredTokens()
        return tokens.2
    }
    
    /// Create a wallet for the authenticated user
    func createWallet(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "PrivyWorkaround", code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        PrivyAuthenticatedService.createEmbeddedWallet { result in
            switch result {
            case .success(let json):
                // Parse wallet info from response
                if let wallet = json["wallet"] as? [String: Any],
                   let address = wallet["address"] as? String,
                   let chainType = wallet["chain_type"] as? String {
                    let walletInfo = WalletInfo(address: address, chainType: chainType, verified: true, walletIndex: 0)
                    completion(.success(walletInfo))
                } else if let address = json["address"] as? String,
                          let chainType = json["chain_type"] as? String ?? "ethereum" as String? {
                    let walletInfo = WalletInfo(address: address, chainType: chainType, verified: true, walletIndex: 0)
                    completion(.success(walletInfo))
                } else {
                    completion(.failure(NSError(domain: "PrivyWorkaround", code: -2,
                                               userInfo: [NSLocalizedDescriptionKey: "Invalid wallet response"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Create embedded wallet (Privy-managed)
    func createEmbeddedWallet(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        print("🔨 [PrivyWorkaroundService] Creating embedded wallet...")
        
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "PrivyWorkaround", code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        // Use the PrivyAuthenticatedService
        PrivyAuthenticatedService.createEmbeddedWallet { result in
            switch result {
            case .success(let json):
                print("✅ [PrivyWorkaroundService] Wallet creation response: \(json)")
                
                // Try various response formats
                if let address = json["address"] as? String {
                    let wallet = WalletInfo(
                        address: address,
                        chainType: json["chain_type"] as? String ?? "ethereum",
                        verified: true,
                        walletIndex: json["wallet_index"] as? Int ?? 0
                    )
                    completion(.success(wallet))
                } else if let wallet = json["wallet"] as? [String: Any],
                          let address = wallet["address"] as? String {
                    let walletInfo = WalletInfo(
                        address: address,
                        chainType: wallet["chain_type"] as? String ?? "ethereum",
                        verified: true,
                        walletIndex: wallet["wallet_index"] as? Int ?? 0
                    )
                    completion(.success(walletInfo))
                } else if let user = json["user"] as? [String: Any],
                          let linkedAccounts = user["linked_accounts"] as? [[String: Any]] {
                    // Look for wallet in linked accounts
                    for account in linkedAccounts {
                        if let type = account["type"] as? String,
                           type == "wallet",
                           let address = account["address"] as? String {
                            let wallet = WalletInfo(
                                address: address,
                                chainType: account["chain_type"] as? String ?? "ethereum",
                                verified: account["verified_at"] != nil,
                                walletIndex: account["wallet_index"] as? Int ?? 0
                            )
                            completion(.success(wallet))
                            return
                        }
                    }
                    completion(.failure(NSError(domain: "PrivyWorkaround", code: -2,
                                               userInfo: [NSLocalizedDescriptionKey: "Wallet not found in response"])))
                } else {
                    completion(.failure(NSError(domain: "PrivyWorkaround", code: -2,
                                               userInfo: [NSLocalizedDescriptionKey: "Invalid wallet response format"])))
                }
                
            case .failure(let error):
                print("❌ [PrivyWorkaroundService] Wallet creation failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Get wallets for the current user
    func getWallets(completion: @escaping (Result<[WalletInfo], Error>) -> Void) {
        print("📊 [PrivyWorkaroundService] Getting user wallets...")
        
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "PrivyWorkaround", code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        getUserData { result in
            switch result {
            case .success(let userData):
                var wallets: [WalletInfo] = []
                
                for account in userData.linkedAccounts {
                    if account["type"] as? String == "wallet",
                       let address = account["address"] as? String,
                       let chainType = account["chain_type"] as? String {
                        let wallet = WalletInfo(
                            address: address,
                            chainType: chainType,
                            verified: account["verified_at"] != nil,
                            walletIndex: account["wallet_index"] as? Int ?? 0
                        )
                        wallets.append(wallet)
                    }
                }
                
                print("✅ [PrivyWorkaroundService] Found \(wallets.count) wallets")
                completion(.success(wallets))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get user data
    func getUserData(completion: @escaping (Result<UserData, Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "PrivyWorkaround", code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        PrivyAuthenticatedService.getCurrentUser { result in
            switch result {
            case .success(let json):
                print("📊 [PrivyWorkaroundService] Parsing user data response: \(json)")
                
                // Handle both direct user data and wrapped user data
                var userData: [String: Any]
                
                if let wrappedUser = json["user"] as? [String: Any] {
                    // Response is wrapped: {"user": {...}}
                    userData = wrappedUser
                    print("✅ [PrivyWorkaroundService] Found wrapped user data")
                } else if json["id"] != nil {
                    // Response is direct user data: {"id": "...", ...}
                    userData = json
                    print("✅ [PrivyWorkaroundService] Found direct user data")
                } else {
                    print("❌ [PrivyWorkaroundService] No valid user data found in response")
                    completion(.failure(NSError(domain: "PrivyWorkaround", code: -2,
                                               userInfo: [NSLocalizedDescriptionKey: "No valid user data in response"])))
                    return
                }
                
                // Parse user data from response
                if let userId = userData["id"] as? String {
                    let userDataResult = UserData(
                        id: userId, 
                        linkedAccounts: userData["linked_accounts"] as? [[String: Any]] ?? []
                    )
                    print("✅ [PrivyWorkaroundService] Successfully parsed user: \(userId)")
                    completion(.success(userDataResult))
                } else {
                    print("❌ [PrivyWorkaroundService] Missing user ID in response")
                    completion(.failure(NSError(domain: "PrivyWorkaround", code: -2,
                                               userInfo: [NSLocalizedDescriptionKey: "Missing user ID in response"])))
                }
            case .failure(let error):
                print("❌ [PrivyWorkaroundService] Failed to get user data: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Logout - clears stored tokens
    func logout() {
        PasskeyService.clearStoredTokens()
    }
    
    // MARK: - Data Models
    
    struct WalletInfo {
        let address: String
        let chainType: String
        let verified: Bool
        let walletIndex: Int
    }
    
    struct UserData {
        let id: String
        let linkedAccounts: [[String: Any]]
    }
}

// MARK: - Extension to make it easier to use in place of SDK

extension PrivyWorkaroundService {
    
    /// Use this instead of PrivyManager.currentUser != nil
    var hasUser: Bool {
        return isAuthenticated
    }
    
    /// Use this to check if wallet operations will work
    var canCreateWallet: Bool {
        return isAuthenticated
    }
} 