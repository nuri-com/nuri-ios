import Foundation
import PrivySDK

/// Ensures the logged-in user has the required embedded wallets.
/// 1) Ethereum (default chain required by Privy backend)
/// 2) Bitcoin Taproot
///
/// Wallet creation is idempotent – Privy will throw if a wallet already exists,
/// so we only call the APIs when the arrays are empty.
struct WalletProvisioner {
    static func ensureWallets() async throws {
        guard let user = PrivyManager.currentUser else { return }

        // 1. Ethereum
        if user.embeddedEthereumWallets.isEmpty {
            _ = try await user.createEthereumWallet(allowAdditional: false)
            print("✅ Created Ethereum wallet")
        }
    }
} 