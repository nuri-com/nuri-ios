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
        print("📦 [PrivyManager] Auth state: \(shared.authState)")
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
            case .authenticatedUnverified(let context):
                print("🟠 [PrivyManager] Auth state: AUTHENTICATED UNVERIFIED - \(context)")
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
                    case .externalWallet(let wallet):
                        print("   🔗 External Wallet: \(wallet)")
                    case .google(let googleAccount):
                        print("   🔍 Google: \(googleAccount)")
                    case .twitter(let twitterAccount):
                        print("   🐦 Twitter: \(twitterAccount)")
                    case .apple(let appleAccount):
                        print("   🍎 Apple: \(appleAccount)")
                    case .discord(let discordAccount):
                        print("   🎮 Discord: \(discordAccount)")
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
    
    /// Force refresh the Privy session with stored tokens
    static func restoreSession() async -> Bool {
        print("🔄 [PrivyManager] Attempting to restore session...")
        
        // Get stored tokens from PasskeyService
        let tokens = PasskeyService.getStoredTokens()
        guard tokens.0 != nil else {
            print("❌ [PrivyManager] No access token found")
            return false
        }
        
        // Wait for Privy to be ready first
        await awaitReady()
        
        // Force a refresh to validate the token
        await refreshUser()
        
        // Check if user is now available
        if let user = currentUser {
            print("✅ [PrivyManager] Session restored successfully for user: \(user.id)")
            return true
        } else {
            print("❌ [PrivyManager] User still nil after restore attempt")
            return false
        }
    }
} 