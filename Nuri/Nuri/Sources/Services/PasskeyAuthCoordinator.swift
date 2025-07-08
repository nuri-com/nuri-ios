import Foundation
import AuthenticationServices
import PrivySDK
import SwiftUI
import UIKit

final class PasskeyAuthCoordinator: NSObject {
    static let shared = PasskeyAuthCoordinator()

    private override init() {}

    /// Launches the **native** passkey sheet powered by the Privy SDK (v2+).
    /// This replaces the deprecated WebAuth flow that hit https://auth.privy.io/passkey.
    func start(relyingParty: String = "https://nuri.com", completion: ((Result<Void, Error>) -> Void)? = nil) {
        print("🔐 [PasskeyAuthCoordinator] Starting sign-in flow...")
        print("   📍 Relying party: \(relyingParty)")
        
        Task { @MainActor in
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.windows.first })
                    .first else {
                print("❌ [PasskeyAuthCoordinator] Failed to get window for presentation")
                completion?(.failure(NSError(domain: "Passkey", code: -1, userInfo: [NSLocalizedDescriptionKey: "No window"])))
                return
            }

            print("✅ [PasskeyAuthCoordinator] Got presentation window, calling PasskeyService.login...")
            
            PasskeyService.shared.login(relyingParty: relyingParty, presentationAnchor: window) { result in
                switch result {
                case .success:
                    print("✅ [PasskeyAuthCoordinator] Native login successful!")
                    print("   🔄 Now provisioning wallets...")
                    Task {
                        do { 
                            try await WalletProvisioner.ensureWallets()
                            print("   ✅ Wallets provisioned successfully")
                        } catch { 
                            print("   ⚠️ Wallet provisioning error:", error)
                        }
                        print("✅ [PasskeyAuthCoordinator] Sign-in flow completed successfully")
                        completion?(.success(()))
                    }
                case .failure(let error):
                    print("❌ [PasskeyAuthCoordinator] Login failed with error:", error)
                    print("   📊 Error domain: \((error as NSError).domain)")
                    print("   📊 Error code: \((error as NSError).code)")
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Launches the **native** passkey registration sheet to create a new credential.
    func register(relyingParty: String = "https://nuri.com", completion: ((Result<Void, Error>) -> Void)? = nil) {
        print("🔐 [PasskeyAuthCoordinator] Starting registration flow...")
        print("   📍 Relying party: \(relyingParty)")
        
        Task { @MainActor in
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.windows.first })
                    .first else {
                print("❌ [PasskeyAuthCoordinator] Failed to get window for presentation")
                completion?(.failure(NSError(domain: "Passkey", code: -1, userInfo: [NSLocalizedDescriptionKey: "No window"])))
                return
            }

            print("✅ [PasskeyAuthCoordinator] Got presentation window, calling PasskeyService.signup...")
            
            PasskeyService.shared.signup(relyingParty: relyingParty, presentationAnchor: window) { result in
                switch result {
                case .success:
                    print("✅ [PasskeyAuthCoordinator] Native signup successful!")
                    print("   🔑 New passkey created and stored in iCloud Keychain")
                    print("   🔄 Now provisioning wallets...")
                    Task {
                        do { 
                            try await WalletProvisioner.ensureWallets()
                            print("   ✅ Wallets provisioned successfully")
                        } catch { 
                            print("   ⚠️ Wallet provisioning error:", error)
                        }
                        print("✅ [PasskeyAuthCoordinator] Registration flow completed successfully")
                        completion?(.success(()))
                    }
                case .failure(let error):
                    print("❌ [PasskeyAuthCoordinator] Signup failed with error:", error)
                    print("   📊 Error domain: \((error as NSError).domain)")
                    print("   📊 Error code: \((error as NSError).code)")
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Attempts to sign-in; if the device holds no compatible passkey it automatically falls back to registration.
    func signInOrRegister(relyingParty: String = "https://nuri.com", completion: ((Result<Void, Error>) -> Void)? = nil) {
        print("🔐 [PasskeyAuthCoordinator] Starting smart sign-in/register flow...")
        print("   📍 Using loginOrRegister to check for existing passkeys first...")
        
        Task { @MainActor in
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.windows.first })
                    .first else {
                print("❌ [PasskeyAuthCoordinator] Failed to get window for presentation")
                completion?(.failure(NSError(domain: "Passkey", code: -1, userInfo: [NSLocalizedDescriptionKey: "No window"])))
                return
            }

            print("✅ [PasskeyAuthCoordinator] Got presentation window, calling PasskeyService.loginOrRegister...")
            
            PasskeyService.shared.loginOrRegister(relyingParty: relyingParty, presentationAnchor: window) { result in
                switch result {
                case .success:
                    print("✅ [PasskeyAuthCoordinator] Smart flow: Login or register succeeded")
                    Task {
                        do { 
                            try await WalletProvisioner.ensureWallets()
                            print("   ✅ Wallets provisioned successfully")
                        } catch { 
                            print("   ⚠️ Wallet provisioning error:", error)
                        }
                        print("✅ [PasskeyAuthCoordinator] Smart flow completed successfully")
                        completion?(.success(()))
                    }
                case .failure(let error):
                    print("❌ [PasskeyAuthCoordinator] Smart flow failed with error:", error)
                    print("   📊 Error domain: \((error as NSError).domain)")
                    print("   📊 Error code: \((error as NSError).code)")
                    completion?(.failure(error))
                }
            }
        }
    }
    
    /// Links an additional passkey to the already authenticated user's account.
    /// This allows adding hardware security keys or additional platform passkeys as backup authentication methods.
    func linkAdditionalPasskey(relyingParty: String = "https://nuri.com", completion: ((Result<Void, Error>) -> Void)? = nil) {
        print("🔐 [PasskeyAuthCoordinator] Starting link additional passkey flow...")
        print("   📍 Current user:", PrivyManager.currentUser?.id ?? "nil")
        
        Task { @MainActor in
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.windows.first })
                    .first else {
                print("❌ [PasskeyAuthCoordinator] Failed to get window for presentation")
                completion?(.failure(NSError(domain: "Passkey", code: -1, userInfo: [NSLocalizedDescriptionKey: "No window"])))
                return
            }
            
            print("✅ [PasskeyAuthCoordinator] Got presentation window, calling PasskeyService.linkAdditionalPasskey...")
            
            PasskeyService.shared.linkAdditionalPasskey(relyingParty: relyingParty, presentationAnchor: window) { result in
                switch result {
                case .success:
                    print("✅ [PasskeyAuthCoordinator] Additional passkey linked successfully!")
                    print("   🔑 User can now authenticate with the new passkey")
                    completion?(.success(()))
                case .failure(let error):
                    print("❌ [PasskeyAuthCoordinator] Link passkey failed with error:", error)
                    print("   📊 Error domain: \((error as NSError).domain)")
                    print("   📊 Error code: \((error as NSError).code)")
                    completion?(.failure(error))
                }
            }
        }
    }
}

// ASWebAuthenticationSession no longer needed – leaving the protocol conformance removed. 