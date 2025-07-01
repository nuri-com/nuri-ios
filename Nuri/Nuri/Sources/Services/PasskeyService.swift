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
        Self.fetchAssertionOptions(relyingParty: relyingParty, appId: appId, clientId: clientId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let options):
                // 2) Always try sign-in first, regardless of allowCredentials
                // The system will check if any passkeys exist for this RP
                PasskeyService.dbg("Attempting sign-in with passkey (allowCredentials: \(options.allowCredentials?.count ?? 0))")
                
                self.performAssertion(with: options, rpId: options.rpId, anchor: window) { assertionResult in
                    switch assertionResult {
                    case .success(let assertionJSON):
                        // 3) Verify the assertion with Privy
                        self.verifyCredential(assertionJSON: assertionJSON, 
                                            challenge: options.challenge,
                                            relyingParty: relyingParty,
                                            appId: appId, 
                                            clientId: clientId,
                                            completion: completion)
                    case .failure(let error):
                        // Check if the error indicates no passkeys exist
                        if let authError = error as? ASAuthorizationError,
                           authError.code == .canceled {
                            // User cancelled or no passkeys exist, try registration
                            PasskeyService.dbg("No passkeys found or user cancelled, falling back to registration")
                            self.signup(relyingParty: relyingParty,
                                      presentationAnchor: window,
                                      completion: completion)
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Links an additional passkey to an already authenticated user.
    /// This allows users to add hardware security keys or platform passkeys as backup authentication methods.
    func linkAdditionalPasskey(relyingParty: String,
                              presentationAnchor window: ASPresentationAnchor,
                              completion: @escaping (Result<Void, Error>) -> Void) {
        // First check if we have a user in the Privy SDK
        guard let user = PrivyManager.currentUser else {
            completion(.failure(NSError(domain: "PasskeyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User must be authenticated to link additional passkeys"])))
            return
        }
        
        let appId = PrivyManager.appId
        let clientId = PrivyManager.clientId
        
        PasskeyService.dbg("Starting linkAdditionalPasskey. appId:", appId, "clientId:", clientId)
        PasskeyService.dbg("Current user ID:", user.id)
        
        // Get the access token from the authenticated user
        Task {
            do {
                let accessToken = try await user.getAccessToken()
                PasskeyService.dbg("Got access token: \(accessToken.prefix(20))...")
                
                // Continue with the linking process
                self.performLinkingWithToken(accessToken: accessToken,
                                            relyingParty: relyingParty,
                                            presentationAnchor: window,
                                            completion: completion)
            } catch {
                PasskeyService.dbg("❌ Failed to get access token: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    private func performLinkingWithToken(accessToken: String,
                                       relyingParty: String,
                                       presentationAnchor window: ASPresentationAnchor,
                                       completion: @escaping (Result<Void, Error>) -> Void) {
        let appId = PrivyManager.appId
        let clientId = PrivyManager.clientId
        
        // For linking, we need to call the register endpoint with the existing user's context
        let challengeURL = URL(string: "https://auth.privy.io/api/v1/passkeys/register/init")!
        
        var req = URLRequest(url: challengeURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appId, forHTTPHeaderField: "privy-app-id")
        req.setValue(clientId, forHTTPHeaderField: "privy-client-id")
        req.setValue("expo:0.53.9", forHTTPHeaderField: "privy-client")
        req.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "x-native-app-identifier")
        
        // Include the access token as Bearer authorization
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        PasskeyService.dbg("Including Bearer token in Authorization header")
        
        let body: [String: Any] = [
            "relying_party": relyingParty
            // Note: Removed "link": true as it might not be needed with proper auth
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            guard let self = self else { return }
            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Link register-init response status:", http.statusCode)
            }
            if let err = err {
                return completion(.failure(err))
            }
            guard let data = data else {
                return completion(.failure(PasskeyError.invalidChallengeResponse))
            }
            
            if let raw = String(data: data, encoding: .utf8) {
                PasskeyService.dbg("⬅️ Link register-init response:", raw)
            }
            
            do {
                // Parse creation options
                let creationOptions: PublicKeyCredentialCreationOptions
                if let env = try? JSONDecoder().decode(CreationEnvelope.self, from: data) {
                    creationOptions = env.options
                } else {
                    creationOptions = try JSONDecoder().decode(PublicKeyCredentialCreationOptions.self, from: data)
                }
                
                // Perform the platform registration
                self.performRegistration(with: creationOptions,
                                       rpId: creationOptions.rp.id,
                                       anchor: window) { result in
                    switch result {
                    case .success(let attestationJSON):
                        self.verifyLinkAttestation(attestationJSON: attestationJSON,
                                                  relyingParty: relyingParty,
                                                  accessToken: accessToken,
                                                  appId: appId,
                                                  clientId: clientId,
                                                  completion: completion)
                    case .failure(let error):
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
            } catch {
                PasskeyService.dbg("❌ Link register-init decode failed")
                completion(.failure(PasskeyError.invalidChallengeResponse))
            }
        }.resume()
    }
    
    private func verifyLinkAttestation(attestationJSON: [String: Any],
                                      relyingParty: String,
                                      accessToken: String,
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
        
        // Include the access token as Bearer authorization
        verifyReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "authenticator_response": attestationJSON,
            "relying_party": relyingParty
        ]
        
        verifyReq.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: verifyReq) { data, resp, err in
            if let http = resp as? HTTPURLResponse {
                PasskeyService.dbg("⬅️ Link verify response status:", http.statusCode)
            }
            if let err = err {
                completion(.failure(err)); return
            }
            guard let data = data else {
                completion(.failure(PasskeyError.verificationFailed("No data"))); return
            }
            
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                PasskeyService.dbg("⬅️ Link verify raw response:", raw)
            }
            
            if let http = resp as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { 
                        PasskeyService.dbg("✅ Additional passkey linked successfully")
                        completion(.success(())) 
                    }
                    
                    // Log the successful authentication and check Privy state
                    Task { @MainActor in
                        PasskeyService.dbg("✅ Authentication successful, checking Privy state...")
                        await PrivyManager.awaitReady()
                        
                        if let user = PrivyManager.currentUser {
                            PasskeyService.dbg("✅ User is now logged in: \(user.id)")
                        } else {
                            PasskeyService.dbg("❌ WARNING: User is still nil after successful auth!")
                        }
                    }
                    
                    return
                }
            }
            
            // Try to extract error message
            let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let msg = errorData?["error"] as? String ?? errorData?["message"] as? String
            completion(.failure(PasskeyError.verificationFailed(msg ?? "Failed to link passkey")))
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
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        guard let challengeData = Data(base64EncodedURLSafe: options.challenge) else {
            return completion(.failure(PasskeyError.invalidChallengeResponse))
        }
        
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        request.userVerificationPreference = .preferred
        
        // If specific credentials are provided, use them
        if let allowCredentials = options.allowCredentials, !allowCredentials.isEmpty {
            request.allowedCredentials = allowCredentials.compactMap { desc in
                guard let data = Data(base64EncodedURLSafe: desc.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: data)
            }
        }
        // If no specific credentials, the system will show all available passkeys for this RP
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AuthorizationDelegate { [weak self] result in
            completion(result)
            self?.activeDelegate = nil
        }
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
            
            // Try to parse the response to get tokens
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let token = json["token"] as? String {
                    PasskeyService.dbg("🎫 Got access token: \(token.prefix(20))...")
                }
                if let refreshToken = json["refresh_token"] as? String {
                    PasskeyService.dbg("🔄 Got refresh token: \(refreshToken.prefix(20))...")
                }
                if let privyAccessToken = json["privy_access_token"] as? String {
                    PasskeyService.dbg("🔑 Got privy access token: \(privyAccessToken.prefix(20))...")
                }
                
                // Store tokens for later use
                if let token = json["token"] as? String,
                   let refreshToken = json["refresh_token"] as? String {
                    // We'll create a method to handle these tokens
                    self.handleAuthenticationTokens(
                        accessToken: token,
                        refreshToken: refreshToken,
                        response: json
                    )
                }
            }
            
            if let http = resp as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { completion(.success(())) }
                    
                    // Log the successful authentication and check Privy state
                    Task { @MainActor in
                        PasskeyService.dbg("✅ Authentication successful, checking Privy state...")
                        await PrivyManager.awaitReady()
                        
                        if let user = PrivyManager.currentUser {
                            PasskeyService.dbg("✅ User is now logged in: \(user.id)")
                        } else {
                            PasskeyService.dbg("❌ WARNING: User is still nil after successful auth!")
                        }
                    }
                    
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

    // MARK: - Token Management
    
    /// Handles authentication tokens received from Privy after successful passkey authentication
    private func handleAuthenticationTokens(accessToken: String, refreshToken: String, response: [String: Any]) {
        PasskeyService.dbg("🔐 Handling authentication tokens...")
        
        // Store tokens securely using Keychain (through Privy SDK's storage)
        // For now, we'll store them in UserDefaults as a temporary solution
        // In production, use Keychain Services
        
        UserDefaults.standard.set(accessToken, forKey: "privy_access_token")
        UserDefaults.standard.set(refreshToken, forKey: "privy_refresh_token")
        
        // Store user data if available
        if let userData = response["user"] as? [String: Any],
           let userId = userData["id"] as? String {
            UserDefaults.standard.set(userId, forKey: "privy_user_id")
            PasskeyService.dbg("👤 Stored user ID: \(userId)")
        }
        
        // Post notification that authentication is complete
        NotificationCenter.default.post(
            name: Notification.Name("PrivyAuthenticationComplete"),
            object: nil,
            userInfo: ["response": response]
        )
        
        PasskeyService.dbg("✅ Authentication tokens stored successfully")
    }
    
    /// Retrieves stored authentication tokens
    static func getStoredTokens() -> (String?, String?, String?) {
        let accessToken = UserDefaults.standard.string(forKey: "privy_access_token")
        let refreshToken = UserDefaults.standard.string(forKey: "privy_refresh_token")
        let userId = UserDefaults.standard.string(forKey: "privy_user_id")
        return (accessToken, refreshToken, userId)
    }
    
    /// Stores authentication tokens
    static func storeAuthTokens(accessToken: String?, refreshToken: String?, userId: String?) {
        if let accessToken = accessToken {
            UserDefaults.standard.set(accessToken, forKey: "privy_access_token")
        }
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "privy_refresh_token")
        }
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: "privy_user_id")
        }
        UserDefaults.standard.synchronize()
        
        PasskeyService.dbg("🗃️ Stored auth tokens - Access: \(accessToken?.prefix(20) ?? "nil")... Refresh: \(refreshToken?.prefix(20) ?? "nil")... User: \(userId ?? "nil")")
    }
    
    /// Clears stored authentication tokens
    static func clearStoredTokens() {
        UserDefaults.standard.removeObject(forKey: "privy_access_token")
        UserDefaults.standard.removeObject(forKey: "privy_refresh_token")
        UserDefaults.standard.removeObject(forKey: "privy_user_id")
        UserDefaults.standard.synchronize()
        PasskeyService.dbg("🗑️ Cleared stored authentication tokens")
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
            
            // Try to parse the response to get tokens
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let token = json["token"] as? String {
                    PasskeyService.dbg("🎫 Got access token: \(token.prefix(20))...")
                }
                if let refreshToken = json["refresh_token"] as? String {
                    PasskeyService.dbg("🔄 Got refresh token: \(refreshToken.prefix(20))...")
                }
                if let privyAccessToken = json["privy_access_token"] as? String {
                    PasskeyService.dbg("🔑 Got privy access token: \(privyAccessToken.prefix(20))...")
                }
                
                // Store tokens for later use
                if let token = json["token"] as? String,
                   let refreshToken = json["refresh_token"] as? String {
                    // We'll create a method to handle these tokens
                    self.handleAuthenticationTokens(
                        accessToken: token,
                        refreshToken: refreshToken,
                        response: json
                    )
                }
            }
            
            if let http = resp as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    DispatchQueue.main.async { completion(.success(())) }
                    
                    // Log the successful authentication and check Privy state
                    Task { @MainActor in
                        PasskeyService.dbg("✅ Authentication successful, checking Privy state...")
                        await PrivyManager.awaitReady()
                        
                        if let user = PrivyManager.currentUser {
                            PasskeyService.dbg("✅ User is now logged in: \(user.id)")
                        } else {
                            PasskeyService.dbg("❌ WARNING: User is still nil after successful auth!")
                        }
                    }
                    
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
