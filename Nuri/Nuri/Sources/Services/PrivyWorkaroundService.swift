import Foundation
import UIKit

/// Workaround service that provides SDK-like functionality using stored tokens
/// This is necessary because the Privy SDK doesn't support native passkeys yet
public class PrivyWorkaroundService {
    
    /// Shared instance
    static let shared = PrivyWorkaroundService()
    
    private var walletCache: (wallets: [WalletInfo], timestamp: Date)?
    private let walletCacheTTL: TimeInterval = 5 // seconds
    
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
                          let chainType = json["chain_type"] as? String ?? "bitcoin-taproot" as String? {
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
    /// Currently creates Ethereum wallets since Bitcoin is only supported in React Native
    func createEmbeddedWallet(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        print("🔨 [PrivyWorkaroundService] Creating embedded Ethereum wallet...")
        print("⚠️ [PrivyWorkaroundService] Bitcoin wallets only supported in React Native (@privy-io/expo)")
        
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "PrivyWorkaround", code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        // Use the PrivyAuthenticatedService to create Ethereum wallet
        PrivyAuthenticatedService.createEmbeddedWallet { result in
            switch result {
            case .success(let json):
                print("✅ [PrivyWorkaroundService] Ethereum wallet creation response: \(json)")
                
                // Parse the response
                if let errors = json["errors"] as? [[String: Any]], !errors.isEmpty {
                    let errorMessage = errors.first?["message"] as? String ?? "Unknown error"
                    print("❌ [PrivyWorkaroundService] Wallet creation error: \(errorMessage)")
                    completion(.failure(NSError(domain: "PrivyWorkaround", code: -2, 
                                               userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else if let address = json["address"] as? String,
                          let chainType = json["chain_type"] as? String ?? "ethereum" as String? {
                    let walletInfo = WalletInfo(address: address, chainType: chainType, verified: true, walletIndex: 0)
                    completion(.success(walletInfo))
                } else {
                    print("❌ [PrivyWorkaroundService] Unexpected response format: \(json)")
                    completion(.failure(NSError(domain: "PrivyWorkaround", code: -3, 
                                               userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"])))
                }
                
            case .failure(let error):
                print("❌ [PrivyWorkaroundService] Ethereum wallet creation failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Create embedded Ethereum wallet (base wallet for Privy)
    func createEthereumWallet(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        print("🔨 [PrivyWorkaroundService] Creating embedded Ethereum wallet...")
        
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "PrivyWorkaround", code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        // Use the PrivyAuthenticatedService
        PrivyAuthenticatedService.createEthereumWallet { result in
            switch result {
            case .success(let json):
                print("✅ [PrivyWorkaroundService] Ethereum wallet creation response: \(json)")
                
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
                print("❌ [PrivyWorkaroundService] Ethereum wallet creation failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Get wallets for the current user, properly categorized by chain type
    func getWallets(completion: @escaping (Result<[WalletInfo], Error>) -> Void) {
        // Serve from cache if fresh to prevent hitting Privy rate-limit.
        if let cache = walletCache, Date().timeIntervalSince(cache.timestamp) < walletCacheTTL {
            print("🔄 [PrivyWorkaroundService] Returning cached wallets (age \(Date().timeIntervalSince(cache.timestamp))s)")
            return completion(.success(cache.wallets))
        }
        print("📊 [PrivyWorkaroundService] Fetching user wallets from API …")
        
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
                    if let type = account["type"] as? String,
                       type == "wallet",
                       let address = account["address"] as? String,
                       let chainType = account["chain_type"] as? String {
                        
                        print("📍 [PrivyWorkaroundService] Found wallet: \(address) (\(chainType))")
                        
                        let walletInfo = WalletInfo(
                            address: address,
                            chainType: chainType,
                            verified: account["verified_at"] != nil,
                            walletIndex: account["wallet_index"] as? Int ?? 0
                        )
                        wallets.append(walletInfo)
                    }
                }
                
                print("✅ [PrivyWorkaroundService] Total wallets found: \(wallets.count)")
                // Update cache
                self.walletCache = (wallets, Date())
                completion(.success(wallets))
                
            case .failure(let error):
                print("❌ [PrivyWorkaroundService] Failed to get wallets: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Get only Ethereum wallets (currently supported in native iOS)
    func getEthereumWallets(completion: @escaping (Result<[WalletInfo], Error>) -> Void) {
        getWallets { result in
            switch result {
            case .success(let allWallets):
                let ethereumWallets = allWallets.filter { $0.chainType.lowercased() == "ethereum" }
                print("💎 [PrivyWorkaroundService] Found \(ethereumWallets.count) Ethereum wallets")
                completion(.success(ethereumWallets))
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
    
    // MARK: - Bitcoin Methods (now implemented via REST API)
    
    /// Returns the user's Bitcoin Taproot wallets (if any). Falls back to empty array.
    func getBitcoinWallets(completion: @escaping (Result<[WalletInfo], Error>) -> Void) {
        print("📊 [PrivyWorkaroundService] Fetching Bitcoin Taproot wallets …")
        getWallets { result in
            switch result {
            case .success(let wallets):
                let btc = wallets.filter { $0.chainType.lowercased().contains("bitcoin") }
                print("💰 [PrivyWorkaroundService] Found \(btc.count) Bitcoin wallets")
                completion(.success(btc))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    /// Creates a Bitcoin wallet using the best available method
    func createBitcoinWallet(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        // Try different approaches in order of preference:
        
        // Option 1: Check if wallet already exists (it might have been created elsewhere)
        getBitcoinWallets { [weak self] result in
            switch result {
            case .success(let wallets):
                if let existingWallet = wallets.first {
                    print("✅ [PrivyWorkaroundService] Bitcoin wallet already exists: \(existingWallet.address)")
                    completion(.success(existingWallet))
                    return
                }
                
                // Option 2: WebView approach (currently disabled due to compilation issues)
                print("⚠️ [PrivyWorkaroundService] WebView approach temporarily disabled")
                
                // Option 3: Backend approach (recommended for production)
                self?.createBitcoinWalletViaBackend(completion: completion)
                
            case .failure(let error):
                print("❌ [PrivyWorkaroundService] Failed to check existing wallets: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Creates a Bitcoin wallet via your backend (recommended approach)
    private func createBitcoinWalletViaBackend(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        print("🌐 [PrivyWorkaroundService] Attempting backend Bitcoin wallet creation...")
        
        // This is where you would call your backend endpoint
        // Your backend would use Privy's NodeJS SDK to create the wallet
        
        // Example implementation:
        /*
        let endpoint = "https://your-backend.com/api/create-bitcoin-wallet"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["userId": currentUserId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }.resume()
        */
        
        // For now, return an informative error
        let error = NSError(
            domain: "PrivyWorkaroundService",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Bitcoin wallet creation requires either:\n1. A backend endpoint using Privy's NodeJS SDK\n2. Using the React Native app\n3. Waiting for Privy to add native iOS support"
            ]
        )
        completion(.failure(error))
    }
    
    /// Creates a Bitcoin wallet by loading Privy SDK in a WebView and using its internal mechanisms
    /// This mimics how the React Native SDK creates Bitcoin wallets
    /// NOTE: Currently disabled due to compilation issues with WKWebView setup
    static func createBitcoinWalletViaWebView(
        chainType: String = "bitcoin-taproot",
        completion: @escaping (Result<WalletInfo, Error>) -> Void
    ) {
        print("🔨 [PrivyWorkaroundService] WebView approach currently disabled")
        
        let error = NSError(
            domain: "PrivyWorkaroundService", 
            code: -1, 
            userInfo: [NSLocalizedDescriptionKey: "WebView approach temporarily disabled due to compilation issues"]
        )
        completion(.failure(error))
        
        /*
        // Original implementation - temporarily commented out
        print("🔨 [PrivyWorkaroundService] Creating Bitcoin \(chainType) wallet via WebView...")
        
        // Get the access token
        let (accessToken, _, userId) = PasskeyService.getStoredTokens()
        guard let token = accessToken else {
            completion(.failure(NSError(domain: "PrivyWorkaroundService", 
                                       code: -1, 
                                       userInfo: [NSLocalizedDescriptionKey: "No access token found"])))
            return
        }
        
        // Create a special web view controller for Bitcoin wallet creation
        DispatchQueue.main.async {
            let webVC = PrivyBitcoinWalletWebViewController()
            webVC.accessToken = token
            webVC.chainType = chainType
            webVC.onWalletCreated = { walletInfo in
                completion(.success(walletInfo))
            }
            webVC.onError = { error in
                completion(.failure(error))
            }
            
            // Present it invisibly
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                webVC.modalPresentationStyle = .overFullScreen
                webVC.view.alpha = 0 // Keep it invisible
                rootVC.present(webVC, animated: false)
            } else {
                completion(.failure(NSError(domain: "PrivyWorkaroundService", 
                                           code: -1, 
                                           userInfo: [NSLocalizedDescriptionKey: "Could not find window"])))
            }
        }
        */
    }
    
    /// Alternative approach: Use the Privy SDK's internal wallet creation mechanism
    /// NOTE: Currently disabled because native SDK doesn't expose Bitcoin wallet creation
    static func createBitcoinWalletViaSDK(
        chainType: String = "bitcoin-taproot",
        completion: @escaping (Result<WalletInfo, Error>) -> Void
    ) {
        print("🔨 [PrivyWorkaroundService] Creating Bitcoin wallet via SDK internals …")
        
        // This approach is currently not feasible because:
        // 1. The native iOS SDK doesn't expose Bitcoin wallet creation methods
        // 2. WalletWithMetadata and other internal types are not available
        // 3. The SDK's internal APIs are not documented for native use
        
        let error = NSError(
            domain: "PrivyWorkaroundService", 
            code: -1, 
            userInfo: [NSLocalizedDescriptionKey: "Bitcoin wallet creation via native SDK is not currently supported. Use WebView or backend approach instead."]
        )
        completion(.failure(error))
        
        /* 
        // This would be the ideal implementation if the SDK supported it:
        Task { @MainActor in
            do {
                // Ensure Privy is ready
                await PrivyManager.awaitReady()
                
                // Get the current user
                guard let user = PrivyManager.currentUser else {
                    throw NSError(domain: "PrivyWorkaroundService", 
                                 code: -1, 
                                 userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])
                }
                
                // Check if user already has a Bitcoin wallet
                // Note: This would require access to internal SDK types
                // if let existingWallet = user.linkedAccounts.first(where: { account in
                //     account.type == .wallet && 
                //     account.chainType == chainType
                // }) {
                //     // Return existing wallet
                // }
                
                // Create new Bitcoin wallet
                // let wallet = try await user.createWallet(chainType: chainType)
                // completion(.success(convertToWalletInfo(wallet)))
                
            } catch {
                completion(.failure(error))
            }
        }
        */
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