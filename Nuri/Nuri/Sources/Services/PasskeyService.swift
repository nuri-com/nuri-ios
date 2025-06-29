import Foundation
import AuthenticationServices
// Temporarily comment out the Swift-SDK import until Privy exposes a stable passkey API for native apps.
// import PrivySDK

/// Errors specific to the Privy passkey round-trip.
public enum PasskeyError: LocalizedError {
    case invalidChallengeResponse
    case appleAuthorizationFailed
    case verificationFailed(String)
    case missingPrivyCredentials
    
    public var errorDescription: String? {
        switch self {
        case .invalidChallengeResponse:
            return "Unable to decode passkey challenge from Privy."
        case .appleAuthorizationFailed:
            return "The device did not return a valid passkey credential."
        case .verificationFailed(let msg):
            return "Privy rejected the credential: \(msg)"
        case .missingPrivyCredentials:
            return "Privy appId / clientId not configured."
        }
    }
}

///  End-to-end helper that performs the whole Privy passkey login in Swift.
///
/// 1.   Fetches a WebAuthn `PublicKeyCredentialRequestOptions` JSON from `auth.privy.io`.
/// 2.   Shows the native Face-ID / Touch-ID sheet to sign the challenge.
/// 3.   POSTs the signed credential back to Privy for verification.
/// 4.   On success stores the resulting Privy session cookie so that the regular Privy SDK picks it up.
final class PasskeyService: NSObject {
    static let shared = PasskeyService()
    private override init() {}

    // Simple debug logger usable from every method.
    static func dbg(_ items: Any...) {
        #if DEBUG
        print("🔎[Passkey]", items.map { "\($0)" }.joined(separator: " "))
        #endif
    }

    // MARK: – Public API
    /// Triggers a passkey login (or signup) with the given relying party.
    /// - Parameters:
    ///   - relyingParty: e.g. "https://nuri.com"
    ///   - window:       The window that should present the Face-ID sheet.
    ///   - completion:   Called on the main queue.
    func login(relyingParty: String,
               presentationAnchor window: ASPresentationAnchor,
               completion: @escaping (Result<Void, Error>) -> Void) {
        let appId = PrivyManager.appId
        let clientId = PrivyManager.clientId

        PasskeyService.dbg("Starting login. appId:", appId, "clientId:", clientId)

        // 1) Download challenge (PublicKeyCredentialRequestOptions) from Privy.
        let challengeURL = URL(string: "https://auth.privy.io/api/v1/passkeys/authenticate/init")!

        var req = URLRequest(url: challengeURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Privy headers that the backend expects (mirrors js-sdk-core / expo)
        req.setValue(appId, forHTTPHeaderField: "privy-app-id")
        req.setValue(clientId, forHTTPHeaderField: "privy-client-id")
        req.setValue("expo:0.53.9", forHTTPHeaderField: "privy-client")
        req.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "x-native-app-identifier")

        let body: [String: Any] = [
            "relying_party": relyingParty
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let json = String(data: req.httpBody ?? Data(), encoding: .utf8) {
            PasskeyService.dbg("➡️ Challenge request body:", json)
        }

        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            guard let self = self else { return }

            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Challenge response status:", http.statusCode)
            }

            if let err = err {
                return completion(.failure(err))
            }

            guard let data = data,
                  let raw = String(data: data, encoding: .utf8) else {
                return completion(.failure(PasskeyError.invalidChallengeResponse))
            }

            do {
                // Privy wraps the request options inside a top-level "options" key.
                let options: PublicKeyCredentialRequestOptions
                if let envelope = try? JSONDecoder().decode(ChallengeEnvelope.self, from: data) {
                    options = envelope.options
                } else {
                    options = try JSONDecoder().decode(PublicKeyCredentialRequestOptions.self, from: data)
                }

                // 2) Present Apple passkey sheet.
                self.performAssertion(with: options, rpId: options.rpId, anchor: window) { result in
                    switch result {
                    case .success(let assertionJSON):
                        // 3) Verify with Privy.
                        self.verifyCredential(assertionJSON: assertionJSON,
                                               challenge: options.challenge,
                                               relyingParty: relyingParty,
                                               appId: appId,
                                               clientId: clientId) { verifyResult in
                            DispatchQueue.main.async {
                                completion(verifyResult)
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            } catch {
                PasskeyService.dbg("❌ Challenge decode failed. Raw:", raw)
                completion(.failure(PasskeyError.invalidChallengeResponse))
            }
        }.resume()
    }

    /// Triggers a passkey **registration** with the given relying party.
    /// On success the new credential is stored on the device and Privy issues a session cookie.
    func signup(relyingParty: String,
                presentationAnchor window: ASPresentationAnchor,
                completion: @escaping (Result<Void, Error>) -> Void) {
        let appId = PrivyManager.appId
        let clientId = PrivyManager.clientId

        PasskeyService.dbg("Starting signup. appId:", appId, "clientId:", clientId)

        // 1) Download creation options (PublicKeyCredentialCreationOptions) from Privy.
        let challengeURL = URL(string: "https://auth.privy.io/api/v1/passkeys/register/init")!

        var req = URLRequest(url: challengeURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appId, forHTTPHeaderField: "privy-app-id")
        req.setValue(clientId, forHTTPHeaderField: "privy-client-id")
        req.setValue("expo:0.53.9", forHTTPHeaderField: "privy-client")
        req.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "x-native-app-identifier")

        let body: [String: Any] = [
            "relying_party": relyingParty
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let json = String(data: req.httpBody ?? Data(), encoding: .utf8) {
            PasskeyService.dbg("➡️ Register-init request body:", json)
        }

        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            guard let self = self else { return }
            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Register-init response status:", http.statusCode)
            }
            if let err = err {
                return completion(.failure(err))
            }
            guard let data = data,
                  let raw = String(data: data, encoding: .utf8) else {
                return completion(.failure(PasskeyError.invalidChallengeResponse))
            }
            do {
                // Privy also wraps creation options inside an envelope.
                let creationOptions: PublicKeyCredentialCreationOptions
                if let env = try? JSONDecoder().decode(CreationEnvelope.self, from: data) {
                    creationOptions = env.options
                } else {
                    creationOptions = try JSONDecoder().decode(PublicKeyCredentialCreationOptions.self, from: data)
                }

                self.performRegistration(with: creationOptions,
                                         rpId: creationOptions.rp.id,
                                         anchor: window) { result in
                    switch result {
                    case .success(let attestationJSON):
                        self.verifyAttestation(attestationJSON: attestationJSON,
                                               challenge: creationOptions.challenge,
                                               relyingParty: relyingParty,
                                               appId: appId,
                                               clientId: clientId) { verifyResult in
                            DispatchQueue.main.async {
                                completion(verifyResult)
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
            } catch {
                PasskeyService.dbg("❌ Register-init decode failed. Raw:", raw)
                completion(.failure(PasskeyError.invalidChallengeResponse))
            }
        }.resume()
    }

    // MARK: – Private helpers
    private func performAssertion(with options: PublicKeyCredentialRequestOptions,
                                  rpId: String,
                                  anchor: ASPresentationAnchor,
                                  completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        guard let challengeData = Data(base64EncodedURLSafe: options.challenge) else {
            return completion(.failure(PasskeyError.invalidChallengeResponse))
        }
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        if let allowed = options.allowCredentials, !allowed.isEmpty {
            request.allowedCredentials = allowed.compactMap { credential in
                guard let idData = Data(base64EncodedURLSafe: credential.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: idData)
            }
        }
        request.userVerificationPreference = .preferred

        let authController = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AuthorizationDelegate(completion: completion)
        authController.delegate = delegate
        authController.presentationContextProvider = delegate
        delegate.anchor = anchor
        authController.performRequests()
    }

    private func verifyCredential(assertionJSON: [String: Any],
                                  challenge: String,
                                  relyingParty: String,
                                  appId: String,
                                  clientId: String,
                                  completion: @escaping (Result<Void, Error>) -> Void) {
        let verifyURL = URL(string: "https://auth.privy.io/api/v1/passkeys/authenticate")!

        var verifyReq = URLRequest(url: verifyURL)
        verifyReq.httpMethod = "POST"
        verifyReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // repeat required Privy headers
        verifyReq.setValue(appId, forHTTPHeaderField: "privy-app-id")
        verifyReq.setValue(clientId, forHTTPHeaderField: "privy-client-id")
        verifyReq.setValue("expo:0.53.9", forHTTPHeaderField: "privy-client")
        verifyReq.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "x-native-app-identifier")

        var body: [String: Any] = [
            "relying_party": relyingParty,
            "challenge": challenge,
            "authenticator_response": assertionJSON
        ]
        verifyReq.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let json = String(data: verifyReq.httpBody ?? Data(), encoding: .utf8) { PasskeyService.dbg("➡️ Verify request body:", json) }

        URLSession.shared.dataTask(with: verifyReq) { data, resp, err in
            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Verify response status:", http.statusCode)
                if (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
            }
            if let err = err { return completion(.failure(err)) }
            let msg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            PasskeyService.dbg("❌ Verify failed. Body:", msg)
            return completion(.failure(PasskeyError.verificationFailed(msg)))
        }.resume()
    }

    // MARK: – Private helpers (registration)
    private func performRegistration(with options: PublicKeyCredentialCreationOptions,
                                     rpId: String,
                                     anchor: ASPresentationAnchor,
                                     completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        guard let challengeData = Data(base64EncodedURLSafe: options.challenge),
              let userIDData = Data(base64EncodedURLSafe: options.user.id) else {
            return completion(.failure(PasskeyError.invalidChallengeResponse))
        }
        let request = provider.createCredentialRegistrationRequest(challenge: challengeData,
                                                                   name: options.user.name,
                                                                   userID: userIDData)
        request.userVerificationPreference = .preferred
        if let exclude = options.excludeCredentials, !exclude.isEmpty {
            request.excludedCredentials = exclude.compactMap { desc in
                guard let data = Data(base64EncodedURLSafe: desc.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: data)
            }
        }

        let authController = ASAuthorizationController(authorizationRequests: [request])
        let delegate = RegistrationDelegate(completion: completion)
        authController.delegate = delegate
        authController.presentationContextProvider = delegate
        delegate.anchor = anchor
        authController.performRequests()
    }

    private func verifyAttestation(attestationJSON: [String: Any],
                                   challenge: String,
                                   relyingParty: String,
                                   appId: String,
                                   clientId: String,
                                   completion: @escaping (Result<Void, Error>) -> Void) {
        let verifyURL = URL(string: "https://auth.privy.io/api/v1/passkeys/register")!

        var verifyReq = URLRequest(url: verifyURL)
        verifyReq.httpMethod = "POST"
        verifyReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        verifyReq.setValue(appId, forHTTPHeaderField: "privy-app-id")
        verifyReq.setValue(clientId, forHTTPHeaderField: "privy-client-id")
        verifyReq.setValue("expo:0.53.9", forHTTPHeaderField: "privy-client")
        verifyReq.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "x-native-app-identifier")

        let body: [String: Any] = [
            "relying_party": relyingParty,
            "challenge": challenge,
            "attestation_response": attestationJSON
        ]
        verifyReq.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let json = String(data: verifyReq.httpBody ?? Data(), encoding: .utf8) {
            PasskeyService.dbg("➡️ Register verify body:", json)
        }

        URLSession.shared.dataTask(with: verifyReq) { data, resp, err in
            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Register verify status:", http.statusCode)
                if (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
            }
            if let err = err { return completion(.failure(err)) }
            let msg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            PasskeyService.dbg("❌ Register verify failed. Body:", msg)
            return completion(.failure(PasskeyError.verificationFailed(msg)))
        }.resume()
    }
}

// MARK: – Apple delegate helper
private final class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var completion: (Result<[String: Any], Error>) -> Void
    weak var anchor: ASPresentationAnchor?

    init(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return anchor ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            return completion(.failure(PasskeyError.appleAuthorizationFailed))
        }
        var json: [String: Any] = [
            "id": cred.credentialID.base64EncodedStringURLSafe(),
            "type": "public-key",
            "rawId": cred.credentialID.base64EncodedStringURLSafe(),
            "response": [
                "authenticatorData": cred.rawAuthenticatorData?.base64EncodedStringURLSafe() ?? "",
                "clientDataJSON": String(data: cred.rawClientDataJSON, encoding: .utf8) ?? "",
                "signature": cred.signature.base64EncodedStringURLSafe()
            ]
        ]
        PasskeyService.dbg("Built assertion payload:", json)
        completion(.success(json))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: – Helper structs for challenge JSON
private struct PublicKeyCredentialRequestOptions: Decodable {
    let challenge: String
    let rpId: String
    let allowCredentials: [CredentialDescriptor]?

    enum CodingKeys: String, CodingKey {
        case challenge
        case rpId = "rp_id"
        case allowCredentials = "allow_credentials"
    }

    struct CredentialDescriptor: Decodable {
        let id: String
    }
}

// MARK: – Base64URL helpers
private extension Data {
    init?(base64EncodedURLSafe input: String) {
        var str = input.replacingOccurrences(of: "-", with: "+")
                         .replacingOccurrences(of: "_", with: "/")
        while str.count % 4 != 0 { str.append("=") }
        self.init(base64Encoded: str)
    }

    func base64EncodedStringURLSafe() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// The backend currently returns the options inside an {"options": {...}} envelope.
private struct ChallengeEnvelope: Decodable {
    let options: PublicKeyCredentialRequestOptions
}

// INSERTION POINT BELOW PRIVATE STRUCTS
// ... existing code ...
private struct PublicKeyCredentialCreationOptions: Decodable {
    let challenge: String
    let rp: RPEntity
    let user: UserEntity
    let excludeCredentials: [CredentialDescriptor]?

    enum CodingKeys: String, CodingKey {
        case challenge
        case rp
        case user
        case excludeCredentials = "exclude_credentials"
    }

    struct RPEntity: Decodable { let id: String; let name: String }
    struct UserEntity: Decodable { let id: String; let name: String; let displayName: String;
        enum CodingKeys: String, CodingKey { case id, name, displayName = "display_name" } }
    struct CredentialDescriptor: Decodable { let id: String }
}

// Envelope for register-init
private struct CreationEnvelope: Decodable { let options: PublicKeyCredentialCreationOptions }

// MARK: – Delegate for registration
private final class RegistrationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var completion: (Result<[String: Any], Error>) -> Void
    weak var anchor: ASPresentationAnchor?
    init(completion: @escaping (Result<[String: Any], Error>) -> Void) { self.completion = completion }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { anchor ?? ASPresentationAnchor() }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            return completion(.failure(PasskeyError.appleAuthorizationFailed))
        }
        let json: [String: Any] = [
            "id": cred.credentialID.base64EncodedStringURLSafe(),
            "type": "public-key",
            "rawId": cred.credentialID.base64EncodedStringURLSafe(),
            "response": [
                "attestationObject": cred.rawAttestationObject?.base64EncodedStringURLSafe() ?? "",
                "clientDataJSON": String(data: cred.rawClientDataJSON, encoding: .utf8) ?? ""
            ]
        ]
        PasskeyService.dbg("Built attestation payload:", json)
        completion(.success(json))
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) { completion(.failure(error)) }
}
// ... existing code ... 