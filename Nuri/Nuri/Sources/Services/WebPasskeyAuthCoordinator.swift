import Foundation
import AuthenticationServices
import UIKit

/// Fallback coordinator that opens Privy's hosted passkey page in a browser session.
/// Works with external security keys that iOS only supports through WebAuthn in Safari/WebKit.
final class WebPasskeyAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebPasskeyAuthCoordinator()
    private override init() {}

    private var session: ASWebAuthenticationSession?

    func start(relyingParty: String = "https://nuri.com", completion: @escaping (Result<Void, Error>) -> Void) {
        guard var comps = URLComponents(string: "https://auth.privy.io/passkey") else {
            return completion(.failure(NSError(domain: "WebPasskey", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad base URL"])))
        }
        comps.queryItems = [
            URLQueryItem(name: "app_id", value: PrivyManager.appId),
            URLQueryItem(name: "client_id", value: PrivyManager.clientId),
            URLQueryItem(name: "relying_party", value: relyingParty),
            URLQueryItem(name: "redirect_uri", value: "nuriwallet://auth-callback")
        ]
        guard let url = comps.url else {
            return completion(.failure(NSError(domain: "WebPasskey", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not build URL"])))
        }

        print("🔑 [WebPasskey] opening", url.absoluteString)

        session = ASWebAuthenticationSession(url: url, callbackURLScheme: "nuriwallet") { callbackURL, error in
            if let error = error {
                print("❌ [WebPasskey] error", error)
                completion(.failure(error))
            } else {
                print("✅ [WebPasskey] redirect", callbackURL?.absoluteString ?? "nil")
                completion(.success(()))
            }
        }
        session?.presentationContextProvider = self
        _ = session?.start()
    }

    // MARK: ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first ?? ASPresentationAnchor()
    }
} 