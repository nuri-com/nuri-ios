import Foundation
import PrivySDK

enum PrivyManager {
    // Replace with your real values from Privy dashboard
    static let appId = "cmaz6gvx500zykw0lfnlv4lrb"
    static let clientId = "client-WY6LLkqWnXYc7pzZRgxosYUCiSHddSsfUaYnW2E9rA1rV"

    static let shared: Privy = {
        let config = PrivyConfig(
            appId: appId,
            appClientId: clientId,
            loggingConfig: .init(logLevel: .verbose)
        )
        let sdk = PrivySdk.initialize(config: config)
        print("📦 [Privy] currentUser:", sdk.user?.id ?? "nil")
        
        // Set up auth state observer
        Task { @MainActor in
            await observeAuthState()
        }
        
        return sdk
    }()

    static var currentUser: PrivyUser? {
        let user = shared.user
        print("📦 [PrivyManager] Getting currentUser: \(user?.id ?? "nil")")
        return user
    }
    
    /// Observes auth state changes and logs them
    static func observeAuthState() async {
        print("🔍 [PrivyManager] Starting auth state observation")
        for await authState in shared.authStateStream {
            switch authState {
            case .notReady:
                print("🔴 [PrivyManager] Auth state: NOT READY")
            case .unauthenticated:
                print("🟡 [PrivyManager] Auth state: UNAUTHENTICATED")
            case .authenticated(let user):
                print("🟢 [PrivyManager] Auth state: AUTHENTICATED - User ID: \(user.id)")
                print("   📧 Linked accounts: \(user.linkedAccounts.count)")
                
                // Log each linked account based on its type
                for account in user.linkedAccounts {
                    switch account {
                    case .phone(let phoneAccount):
                        print("   📱 Phone: \(phoneAccount)")
                    case .email(let emailAccount):
                        print("   📧 Email: \(emailAccount)")
                    case .customAuth(let customAuth):
                        print("   🔐 Custom Auth: \(customAuth)")
                    case .embeddedEthereumWallet(let wallet):
                        print("   💳 Ethereum Wallet: \(wallet)")
                    case .embeddedSolanaWallet(let wallet):
                        print("   💳 Solana Wallet: \(wallet)")
                    // Note: Add more cases as they become available in the SDK
                    // OAuth providers like .google, .apple, .discord, etc. might be added later
                    // Passkey support is currently handled through web authentication
                    @unknown default:
                        print("   ❓ Unknown account type: \(account)")
                    }
                }
                
                // Check specifically for passkey accounts if they exist in the enum
                // Note: Passkey might be part of customAuth or a separate case
            @unknown default:
                print("❓ [PrivyManager] Unknown auth state")
            }
        }
    }
    
    /// Refreshes the current user data
    static func refreshUser() async {
        print("🔄 [PrivyManager] Refreshing user...")
        if let user = currentUser {
            do {
                try await user.refresh()
                print("✅ [PrivyManager] User refreshed successfully")
            } catch {
                print("❌ [PrivyManager] Failed to refresh user: \(error)")
            }
        } else {
            print("⚠️ [PrivyManager] No user to refresh")
        }
    }
    
    /// Checks if Privy is ready
    static func awaitReady() async {
        print("⏳ [PrivyManager] Waiting for Privy to be ready...")
        await shared.awaitReady()
        print("✅ [PrivyManager] Privy is ready")
        print("   📊 Current auth state: \(shared.authState)")
        if let user = currentUser {
            print("   👤 User found: \(user.id)")
        } else {
            print("   ❌ No user found after ready")
        }
    }
} 