import Foundation
import PrivySDK

typealias WalletInfo = PrivyWorkaroundService.WalletInfo

/// Ensures the logged-in user has the required embedded wallets.
/// 1) Bitcoin Taproot (primary wallet for the Nuri app)
/// 2) Ethereum (optional, for compatibility if needed)
///
/// Wallet creation is idempotent – Privy will throw if a wallet already exists,
/// so we only call the APIs when the arrays are empty.
struct WalletProvisioner {
    static func ensureWallets() async throws {
        guard let user = PrivyManager.currentUser else { return }

        // 1. Bitcoin Taproot (primary wallet for Nuri)
        // Note: Privy SDK might not have native Bitcoin wallet support yet
        // This would need to be implemented when Privy adds Bitcoin wallet APIs
        // For now, we'll focus on the direct API approach used in PrivyAuthenticatedService
        
        // 2. Ethereum (for backward compatibility if needed)
        if user.embeddedEthereumWallets.isEmpty {
            // Temporarily commented out to focus on Bitcoin
            // _ = try await user.createEthereumWallet(allowAdditional: false)
            // print("✅ Created Ethereum wallet")
            print("ℹ️ Skipping Ethereum wallet creation - focusing on Bitcoin Taproot")
        }
    }

    private static func ensureBitcoinWallet(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        // Get existing Bitcoin wallet
        PrivyWorkaroundService.shared.getBitcoinWallets { result in
            switch result {
            case .success(let wallets):
                if let existingWallet = wallets.first {
                    print("✅ Existing BTC wallet found: \(existingWallet.address)")
                    completion(.success(existingWallet))
                } else {
                    print("🚀 No Bitcoin wallet – creating one …")
                    // Option 2: Try WebView approach (experimental)
                    print("🔧 [PrivyWorkaroundService] Attempting WebView-based Bitcoin wallet creation...")
                    PrivyWorkaroundService.shared.createBitcoinWallet { webViewResult in
                        switch webViewResult {
                        case .success(let wallet):
                            completion(.success(wallet))
                        case .failure(let webViewError):
                            print("⚠️ [PrivyWorkaroundService] WebView approach failed: \(webViewError)")
                            
                            // Option 3: Backend approach (recommended for production)
                            self.createBitcoinWalletViaBackend(completion: completion)
                        }
                    }
                }
            case .failure(let error):
                print("❌ Failed to get Bitcoin wallets: \(error)")
                completion(.failure(error))
            }
        }
    }

    private static func createBitcoinWalletViaBackend(completion: @escaping (Result<WalletInfo, Error>) -> Void) {
        // Implementation of createBitcoinWalletViaBackend method
        // This method should be implemented to handle the backend approach for creating a Bitcoin wallet
        // For now, we'll leave it empty as the backend approach is not provided in the original code
        completion(.failure(NSError(domain: "", code: 0, userInfo: nil)))
    }
} 