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
    case noCredentialFound
    
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
        case .noCredentialFound:
            return "No existing passkey found for this device."
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
    private var activeDelegate: NSObject?
    
    private override init() {}

    // Simple debug logger usable from every method.
    static func dbg(_ items: Any...) {
        #if DEBUG
        print("🔎[Passkey]", items.map { "\($0)" }.joined(separator: " "))
        #endif
    }

    // MARK: – Public API
    /// Triggers a passkey login (or registration if none exists) with the given relying party.
    ///
    /// If no passkey exists, registration is triggered. Otherwise, sign-in is performed.
    func loginOrRegister(relyingParty: String,
                        presentationAnchor window: ASPresentationAnchor,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        let appId = PrivyManager.appId
        let clientId = PrivyManager.clientId

        PasskeyService.dbg("Starting loginOrRegister. appId:", appId, "clientId:", clientId)

        // 1) Fetch assertion options (authenticate/init)
        Self.fetchAssertionOptions(relyingParty: relyingParty, appId: appId, clientId: clientId) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let options):
                // 2) Check if any passkeys exist for this user
                if options.allowCredentials == nil || options.allowCredentials?.isEmpty == true {
                    // No passkey: trigger registration
                    PasskeyService.dbg("No passkey found (allowCredentials nil or empty), triggering registration")
                    self.signup(relyingParty: relyingParty, presentationAnchor: window, completion: completion)
                } else {
                    // Passkey exists: trigger sign-in
                    PasskeyService.dbg("Passkey found, triggering sign-in")
                    self.login(relyingParty: relyingParty, presentationAnchor: window, completion: completion)
                }
            }
        }
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

    /// Triggers a passkey sign-in with the given relying party.
    func login(relyingParty: String,
               presentationAnchor window: ASPresentationAnchor,
               completion: @escaping (Result<Void, Error>) -> Void) {
        let appId = PrivyManager.appId
        let clientId = PrivyManager.clientId

        PasskeyService.dbg("Starting login. appId:", appId, "clientId:", clientId)

        Self.fetchAssertionOptions(relyingParty: relyingParty, appId: appId, clientId: clientId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let options):
                self.performAssertion(with: options, rpId: options.rpId, anchor: window) { result in
                    switch result {
                    case .success(let assertionJSON):
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
            }
        }
    }

    // MARK: – Private helpers
    private func performAssertion(with options: PublicKeyCredentialRequestOptions,
                                  rpId: String,
                                  anchor: ASPresentationAnchor,
                                  completion: @escaping (Result<[String: Any], Error>) -> Void) {
        PasskeyService.dbg("[performAssertion] Presenting Apple passkey sheet – rpId:", rpId)
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
        let delegate = AuthorizationDelegate { [weak self] result in
            completion(result)
            self?.activeDelegate = nil
        }
        delegate.verbose = true
        self.activeDelegate = delegate
        
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

        let body: [String: Any] = [
            "authenticator_response": assertionJSON,
            "relying_party": relyingParty,
            "challenge": challenge
        ]
        verifyReq.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let preview = String(data: verifyReq.httpBody ?? Data(), encoding: .utf8)?.prefix(400) {
            PasskeyService.dbg("➡️ Verify request body (truncated):", preview)
        }

        URLSession.shared.dataTask(with: verifyReq) { data, resp, err in
            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Verify response status:", http.statusCode)
                if let fields = http.allHeaderFields as? [String: String],
                   let url = verifyReq.url {
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                    for cookie in cookies {
                        PasskeyService.dbg("🍪 Set-Cookie:", cookie)
                        HTTPCookieStorage.shared.setCookie(cookie)
                        // Debug: print all cookies after setting
                        let allCookies = HTTPCookieStorage.shared.cookies ?? []
                        for c in allCookies {
                            PasskeyService.dbg("🍪 [All Cookies]", c)
                        }
                    }
                }
            }
            if let err = err {
                completion(.failure(err)); return
            }
            guard let data = data else {
                completion(.failure(PasskeyError.verificationFailed("No data"))); return
            }
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                PasskeyService.dbg("⬅️ Verify raw response:", raw)
            }
            if let http = resp as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
            }
            // Try to extract error message
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            completion(.failure(PasskeyError.verificationFailed(msg ?? "Unknown error")))
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
        let delegate = RegistrationDelegate { [weak self] result in
            completion(result)
            self?.activeDelegate = nil
        }
        self.activeDelegate = delegate
        
        authController.delegate = delegate
        authController.presentationContextProvider = delegate
        delegate.anchor = anchor
        authController.performRequests()
    }

    private func verifyAttestation(attestationJSON: [String: Any],
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

        // Check if we need to pass attestation data differently
        // Some APIs expect the attestation response to be flattened
        let body: [String: Any] = [
            "authenticator_response": attestationJSON,
            "relying_party": relyingParty,
        ]
        
        PasskeyService.dbg("🔍 Attestation JSON structure:", attestationJSON)
        verifyReq.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let requestData = verifyReq.httpBody,
           let requestJSON = String(data: requestData, encoding: .utf8) {
            PasskeyService.dbg("➡️ Register verify request body:", requestJSON)
        }

        URLSession.shared.dataTask(with: verifyReq) { data, resp, err in
            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Register verify response status:", http.statusCode)
                if let fields = http.allHeaderFields as? [String: String],
                   let url = verifyReq.url {
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                    for cookie in cookies {
                        PasskeyService.dbg("🍪 Set-Cookie:", cookie)
                        HTTPCookieStorage.shared.setCookie(cookie)
                        // Debug: print all cookies after setting
                        let allCookies = HTTPCookieStorage.shared.cookies ?? []
                        for c in allCookies {
                            PasskeyService.dbg("🍪 [All Cookies]", c)
                        }
                    }
                }
            }
            if let err = err {
                completion(.failure(err)); return
            }
            guard let data = data else {
                completion(.failure(PasskeyError.verificationFailed("No data"))); return
            }
            
            // Always log the raw response for debugging
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                PasskeyService.dbg("⬅️ Register verify raw response:", raw)
            }
            
            if let http = resp as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { completion(.success(())) }
                    return
                }
            }
            // Try to extract error message
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorData?["error"] as? String ?? errorData?["message"] as? String
            PasskeyService.dbg("❌ Register verify error data:", errorData ?? "no error data")
            completion(.failure(PasskeyError.verificationFailed(msg ?? "Unknown error")))
        }.resume()
    }

    // MARK: - Private helpers
    /// Fetches assertion options from Privy (authenticate/init)
    private static func fetchAssertionOptions(relyingParty: String, appId: String, clientId: String, completion: @escaping (Result<PublicKeyCredentialRequestOptions, Error>) -> Void) {
        let challengeURL = URL(string: "https://auth.privy.io/api/v1/passkeys/authenticate/init")!
        var req = URLRequest(url: challengeURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appId, forHTTPHeaderField: "privy-app-id")
        req.setValue(clientId, forHTTPHeaderField: "privy-client-id")
        req.setValue("expo:0.53.9", forHTTPHeaderField: "privy-client")
        req.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "x-native-app-identifier")
        let body: [String: Any] = ["relying_party": relyingParty]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        PasskeyService.dbg("[fetchAssertionOptions] relying_party:", relyingParty)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(.failure(err)); return
            }
            guard let data = data else {
                completion(.failure(PasskeyError.invalidChallengeResponse)); return
            }
            do {
                let raw = String(data: data, encoding: .utf8) ?? "<no data>"
                PasskeyService.dbg("[fetchAssertionOptions] raw backend response:", raw)
                // Privy wraps the request options inside a top-level "options" key.
                let options: PublicKeyCredentialRequestOptions
                if let envelope = try? JSONDecoder().decode(ChallengeEnvelope.self, from: data) {
                    options = envelope.options
                } else {
                    options = try JSONDecoder().decode(PublicKeyCredentialRequestOptions.self, from: data)
                }
                PasskeyService.dbg("[fetchAssertionOptions] allowCredentials count:", options.allowCredentials?.count ?? -1)
                completion(.success(options))
            } catch {
                completion(.failure(PasskeyError.invalidChallengeResponse))
            }
        }.resume()
    }
}

// MARK: – Apple delegate helper
private final class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var completion: (Result<[String: Any], Error>) -> Void
    weak var anchor: ASPresentationAnchor?
    var verbose: Bool = false

    init(_ completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return anchor ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            completion(.failure(PasskeyError.appleAuthorizationFailed))
            return
        }
        let json: [String: Any] = [
            "id": cred.credentialID.base64EncodedStringURLSafe(),
            "type": "public-key",
            "raw_id": cred.credentialID.base64EncodedStringURLSafe(),
            "response": [
                "authenticator_data": cred.rawAuthenticatorData?.base64EncodedStringURLSafe() ?? "",
                // client_data_json should be base64url encoded, not a string
                "client_data_json": cred.rawClientDataJSON.base64EncodedStringURLSafe(),
                "signature": cred.signature.base64EncodedStringURLSafe()
            ],
            "client_extension_results": [String: Any]()
        ]
        if verbose {
            PasskeyService.dbg("✅ [Apple] Built assertion payload. id:", json["id"] ?? "?", "sig bytes:", (cred.signature as NSData).length)
        }
        completion(.success(json))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        PasskeyService.dbg("❌ [Apple] authorization error", error)
        completion(.failure(error))
    }
}

// MARK: - Registration Delegate
private final class RegistrationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var completion: (Result<[String: Any], Error>) -> Void
    weak var anchor: ASPresentationAnchor?

    init(_ completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return anchor ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            completion(.failure(PasskeyError.appleAuthorizationFailed))
            return
        }
        let json: [String: Any] = [
            "id": cred.credentialID.base64EncodedStringURLSafe(),
            "type": "public-key",
            "raw_id": cred.credentialID.base64EncodedStringURLSafe(),
            "response": [
                "attestation_object": cred.rawAttestationObject?.base64EncodedStringURLSafe() ?? "",
                // client_data_json should be base64url encoded, not a string
                "client_data_json": cred.rawClientDataJSON.base64EncodedStringURLSafe()
            ],
            "client_extension_results": [String: Any]()
        ]
        
        // Debug: Log clientDataJSON content
        if let clientDataJSON = String(data: cred.rawClientDataJSON, encoding: .utf8) {
            PasskeyService.dbg("📋 clientDataJSON content:", clientDataJSON)
        }
        
        PasskeyService.dbg("Built attestation payload:", json)
        completion(.success(json))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        PasskeyService.dbg("❌ [Apple] registration error", error)
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

// Envelope for register-init
private struct CreationEnvelope: Decodable {
    let options: PublicKeyCredentialCreationOptions
}

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
