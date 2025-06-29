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
        Task { @MainActor in
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.windows.first })
                    .first else {
                completion?(.failure(NSError(domain: "Passkey", code: -1, userInfo: [NSLocalizedDescriptionKey: "No window"])))
                return
            }

            PasskeyService.shared.login(relyingParty: relyingParty, presentationAnchor: window) { result in
                switch result {
                case .success:
                    print("✅ [Passkey] native login successful")
                    completion?(.success(()))
                case .failure(let error):
                    print("❌ [Passkey] login error", error)
                    completion?(.failure(error))
                }
            }
        }
    }
}

// ASWebAuthenticationSession no longer needed – leaving the protocol conformance removed. 