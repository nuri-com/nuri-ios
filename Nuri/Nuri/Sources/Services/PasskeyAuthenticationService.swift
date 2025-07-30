import Foundation
import AuthenticationServices

// MARK: - Base64URL Extensions

extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if necessary
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)
        
        self.init(base64Encoded: base64)
    }
}

@MainActor
final class PasskeyAuthenticationService: NSObject {
    static let shared = PasskeyAuthenticationService()
    
    // Configuration
    private var baseURL: String {
        // Always use production passkey server
        return "https://passkey.nuri.com"
    }
    private let relyingPartyIdentifier = "nuri.com" // Using parent domain for passkeys
    
    private override init() {
        super.init()
        Log.passkey.info("Service initialized", metadata: [
            "baseURL": baseURL,
            "relyingPartyId": relyingPartyIdentifier
        ])
    }
    
    // MARK: - Authentication Models
    
    struct AuthenticationOptionsResponse: Codable {
        let challenge: String
        let timeout: Int
        let rpId: String
        let userVerification: String
    }
    
    // Structure that matches SimpleWebAuthn expectations
    struct AuthenticationVerificationRequest: Codable {
        let cred: CredentialData
        
        struct CredentialData: Codable {
            let id: String
            let rawId: String
            let type: String = "public-key"
            let response: ResponseData // SimpleWebAuthn expects auth data nested under 'response'
            
            struct ResponseData: Codable {
                let authenticatorData: String
                let clientDataJSON: String
                let signature: String
                let userHandle: String?
            }
        }
    }
    
    // Alternative: Standard SimpleWebAuthn structure (no cred wrapper)
    struct SimpleWebAuthnVerificationRequest: Codable {
        let id: String
        let rawId: String
        let type: String
        let response: ResponseData
        
        struct ResponseData: Codable {
            let authenticatorData: String
            let clientDataJSON: String
            let signature: String
            let userHandle: String?
        }
    }
    
    struct AuthenticationVerificationResponse: Codable {
        let verified: Bool
        let username: String?
        let isAnonymous: Bool
    }
    
    struct RegistrationOptionsResponse: Decodable {
        let challenge: String
        let rp: RelyingParty
        let user: User
        let pubKeyCredParams: [PublicKeyCredentialParameters]
        let timeout: Int
        let authenticatorSelection: AuthenticatorSelection
        let attestation: String
        let challengeKey: String
        
        struct RelyingParty: Codable {
            let id: String
            let name: String
        }
        
        struct User: Codable {
            let id: String
            let name: String
            let displayName: String
        }
        
        struct PublicKeyCredentialParameters: Codable {
            let type: String
            let alg: Int
        }
        
        struct AuthenticatorSelection: Codable {
            let residentKey: String?
            let requireResidentKey: Bool
            let userVerification: String
            let authenticatorAttachment: String?
        }
    }
    
    struct RegistrationVerificationRequest: Codable {
        let cred: CredentialData
        let challengeKey: String
        let username: String?
        
        struct CredentialData: Codable {
            let id: String
            let rawId: String
            let type: String
            let response: ResponseData
            
            struct ResponseData: Codable {
                let clientDataJSON: String
                let attestationObject: String
            }
        }
    }
    
    struct RegistrationVerificationResponse: Codable {
        let verified: Bool
        let username: String?
        let isAnonymous: Bool
    }
    
    // MARK: - User Data Storage
    
    struct UserDataRequest: Codable {
        let email: String?
        let encryptedData: EncryptedData
        let authProof: String
        let credentialId: String?
        
        struct EncryptedData: Codable {
            let encryptionKey: String
            let keyFormat: String
            let createdAt: String
            let deviceName: String
        }
    }
    
    struct UserDataResponse: Codable {
        let success: Bool
        let username: String
        let email: String?
        let hasEncryptedData: Bool
        let updatedAt: String
    }
    
    struct UserDataGetResponse: Codable {
        let username: String
        let email: String?
        let encryptedData: UserDataRequest.EncryptedData?
        let createdAt: String
        let updatedAt: String
    }
    
    // MARK: - Main Authentication Flow
    
    func authenticateWithPasskey(presentationAnchor: ASPresentationAnchor) async throws -> (verified: Bool, username: String?, isAnonymous: Bool) {
        Log.passkey.info("Starting passkey authentication flow")
        
        // Store the presentation anchor
        self.currentPresentationAnchor = presentationAnchor
        defer { self.currentPresentationAnchor = nil }
        
        // Step 1: Get authentication options
        Log.passkey.info("Step 1: Fetching authentication options")
        let authOptions = try await fetchAuthenticationOptions()
        Log.passkey.success("Received auth options", metadata: [
            "challengeLength": authOptions.challenge.count,
            "rpId": authOptions.rpId
        ])
        
        // Step 2: Create credential assertion request
        Log.passkey.info("Step 2: Creating credential assertion request")
        let challenge = Data(base64URLEncoded: authOptions.challenge) ?? Data()
        
        // Use the rpId from the server response
        let rpId = authOptions.rpId
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)
        
        Log.passkey.success("Assertion request created", metadata: [
            "challengeSize": challenge.count,
            "rpId": rpId
        ])
        
        // Step 3: Perform authorization
        Log.passkey.info("Step 3: Presenting passkey UI")
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        
        do {
            let authorization = try await performAuthorization(controller: authController)
            
            if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                Log.passkey.success("User selected credential", metadata: [
                    "credentialId": credential.credentialID.base64URLEncodedString(),
                    "userHandle": credential.userID.base64URLEncodedString(),
                    "authenticatorDataSize": credential.rawAuthenticatorData.count,
                    "clientDataJSONSize": credential.rawClientDataJSON.count,
                    "signatureSize": credential.signature.count
                ])
                
                // Step 4: Verify with server
                Log.passkey.info("Step 4: Verifying with server")
                let result = try await verifyAuthentication(credential: credential)
                
                // Step 5: Check if there's a stored encryption key (for informational purposes)
                if result.verified, let username = result.username {
                    // Store user info for later use
                    UserDefaults.standard.set(username, forKey: "passkeyUsername")
                    UserDefaults.standard.set(credential.credentialID.base64URLEncodedString(), forKey: "passkeyCredentialId")
                    UserDefaults.standard.set(result.isAnonymous, forKey: "passkeyIsAnonymous")
                    
                    Log.passkey.info("Step 5: Checking for backed up encryption key", metadata: [
                        "username": username,
                        "isAnonymous": result.isAnonymous
                    ])
                    
                    if let storedKey = try? await retrieveEncryptionKey(
                        for: username,
                        credentialId: credential.credentialID.base64URLEncodedString(),
                        isAnonymous: result.isAnonymous
                    ) {
                        Log.passkey.success("Found backed up encryption key on server", metadata: [
                            "keyPrefix": String(storedKey.prefix(10)) + "..."
                        ])
                        // The key is available if the user needs to recover their wallet
                        // It's NOT automatically imported - that's a manual process
                    } else {
                        Log.passkey.info("No backed up encryption key found on server")
                    }
                }
                
                return result
            } else {
                Log.passkey.error("Invalid credential type received")
                throw PasskeyError.invalidCredentialType
            }
        } catch {
            Log.passkey.error("Authorization failed", error: error)
            
            // Check if error is "no credentials found"
            if let authError = error as? ASAuthorizationError {
                Log.passkey.debug("ASAuthorizationError", metadata: [
                    "code": authError.code.rawValue
                ])
                
                if authError.code == .canceled {
                    Log.passkey.info("User canceled the operation")
                } else if authError.code == .unknown {
                    Log.passkey.warning("Unknown error - likely no passkeys")
                    throw PasskeyError.noPasskeysFound
                }
            }
            throw error
        }
    }
    
    func createPasskey(username: String? = nil, presentationAnchor: ASPresentationAnchor) async throws -> (verified: Bool, username: String?) {
        // Store the presentation anchor
        self.currentPresentationAnchor = presentationAnchor
        defer { self.currentPresentationAnchor = nil }
        
        // Step 1: Get registration options
        let regOptions = try await fetchRegistrationOptions(username: username)
        
        // Step 2: Create credential registration request
        let challenge = Data(base64URLEncoded: regOptions.challenge) ?? Data()
        let userID = Data(regOptions.user.id.utf8)
        
        // Use the rpId from the server response
        let rpId = regOptions.rp.id
        Log.passkey.info("Using server's rpId for registration", metadata: ["rpId": rpId])
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let registrationRequest = platformProvider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: regOptions.user.name,
            userID: userID
        )
        
        // Step 3: Perform authorization
        let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        
        let authorization = try await performAuthorization(controller: authController)
        
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            // Step 4: Verify with server
            let result = try await verifyRegistration(credential: credential, username: username, challengeKey: regOptions.challengeKey)
            
            // Step 5: Store encryption key if registration successful
            if result.verified, let username = result.username {
                Log.passkey.info("Step 5: Storing encryption key with passkey", metadata: [
                    "username": username,
                    "credentialId": credential.credentialID.base64URLEncodedString().prefix(10) + "...",
                    "isAnonymous": username.starts(with: "anon_") || username == "Anonymous"
                ])
                
                // Store user info for later use
                UserDefaults.standard.set(username, forKey: "passkeyUsername")
                UserDefaults.standard.set(credential.credentialID.base64URLEncodedString(), forKey: "passkeyCredentialId")
                UserDefaults.standard.set(username.starts(with: "anon_") || username == "Anonymous", forKey: "passkeyIsAnonymous")
                
                do {
                    try await storeEncryptionKey(
                        for: username,
                        credentialId: credential.credentialID.base64URLEncodedString(),
                        isAnonymous: username.starts(with: "anon_") || username == "Anonymous"
                    )
                    Log.passkey.success("Encryption key stored successfully with passkey")
                } catch {
                    Log.passkey.error("Failed to store encryption key", error: error)
                    // Don't fail the registration if key storage fails
                }
            } else {
                Log.passkey.error("Cannot store encryption key - registration not verified or no username", metadata: [
                    "verified": result.verified,
                    "hasUsername": result.username != nil
                ])
            }
            
            return result
        } else {
            throw PasskeyError.invalidCredentialType
        }
    }
    
    // MARK: - API Methods
    
    private func fetchAuthenticationOptions() async throws -> AuthenticationOptionsResponse {
        let endpoint = "\(baseURL)/generate-authentication-options"
        
        guard let url = URL(string: endpoint) else {
            Log.network.error("Invalid URL", metadata: ["endpoint": endpoint])
            throw PasskeyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        Log.network.info("Sending auth options request", metadata: ["url": endpoint])
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.network.error("Invalid response type")
            throw PasskeyError.serverError
        }
        
        Log.network.info("Response received", metadata: [
            "status": httpResponse.statusCode,
            "contentLength": data.count
        ])
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.network.error("Server error", metadata: [
                "status": httpResponse.statusCode,
                "body": errorString
            ])
            throw PasskeyError.serverError
        }
        
        let authOptions = try JSONDecoder().decode(AuthenticationOptionsResponse.self, from: data)
        Log.network.success("Auth options received", metadata: [
            "rpId": authOptions.rpId,
            "userVerification": authOptions.userVerification
        ])
        return authOptions
    }
    
    private func verifyAuthentication(credential: ASAuthorizationPlatformPublicKeyCredentialAssertion) async throws -> (verified: Bool, username: String?, isAnonymous: Bool) {
        let endpoint = "\(baseURL)/verify-authentication"
        
        guard let url = URL(string: endpoint) else {
            Log.network.error("Invalid URL", metadata: ["endpoint": endpoint])
            throw PasskeyError.invalidURL
        }
        
        let credentialIdBase64 = credential.credentialID.base64URLEncodedString()
        
        let verificationRequest = AuthenticationVerificationRequest(
            cred: AuthenticationVerificationRequest.CredentialData(
                id: credentialIdBase64,
                rawId: credentialIdBase64,
                response: AuthenticationVerificationRequest.CredentialData.ResponseData(
                    authenticatorData: credential.rawAuthenticatorData.base64URLEncodedString(),
                    clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
                    signature: credential.signature.base64URLEncodedString(),
                    userHandle: credential.userID.base64URLEncodedString()
                )
            )
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        request.httpBody = try encoder.encode(verificationRequest)
        
        // Debug logging
        Log.passkey.debug("Verification request", metadata: [
            "credentialId": credentialIdBase64,
            "credentialIdLength": credential.credentialID.count,
            "userHandle": credential.userID.base64URLEncodedString(),
            "authenticatorDataSize": credential.rawAuthenticatorData.count,
            "signatureSize": credential.signature.count
        ])
        
        #if DEBUG
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            Log.passkey.debug("Request JSON", metadata: ["body": jsonString])
        }
        #endif
        
        // Debug: Decode clientDataJSON
        if let clientDataJSON = try? JSONSerialization.jsonObject(with: credential.rawClientDataJSON, options: []) as? [String: Any] {
            Log.passkey.debug("Client data JSON decoded", metadata: clientDataJSON)
        }
        
        Log.network.info("Sending verification request")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.network.error("Invalid response type")
            throw PasskeyError.serverError
        }
        
        Log.network.info("Verification response", metadata: [
            "status": httpResponse.statusCode
        ])
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.network.error("Server verification error", metadata: [
                "status": httpResponse.statusCode,
                "response": errorString
            ])
            throw PasskeyError.serverError
        }
        
        do {
            let verificationResponse = try JSONDecoder().decode(AuthenticationVerificationResponse.self, from: data)
            Log.passkey.success("Verification successful", metadata: [
                "verified": verificationResponse.verified,
                "username": verificationResponse.username ?? "anonymous",
                "isAnonymous": verificationResponse.isAnonymous
            ])
            return (verificationResponse.verified, verificationResponse.username, verificationResponse.isAnonymous)
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            Log.network.error("Failed to decode verification response", error: error, metadata: [
                "rawResponse": responseString
            ])
            throw error
        }
    }
    
    private func fetchRegistrationOptions(username: String?) async throws -> RegistrationOptionsResponse {
        guard var urlComponents = URLComponents(string: "\(baseURL)/generate-registration-options") else {
            throw PasskeyError.invalidURL
        }
        
        if let username = username {
            urlComponents.queryItems = [URLQueryItem(name: "username", value: username)]
        }
        
        guard let url = urlComponents.url else {
            throw PasskeyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PasskeyError.serverError
        }
        
        return try JSONDecoder().decode(RegistrationOptionsResponse.self, from: data)
    }
    
    private func verifyRegistration(credential: ASAuthorizationPlatformPublicKeyCredentialRegistration, username: String?, challengeKey: String) async throws -> (verified: Bool, username: String?) {
        guard let url = URL(string: "\(baseURL)/verify-registration") else {
            throw PasskeyError.invalidURL
        }
        
        let credentialIdBase64 = credential.credentialID.base64URLEncodedString()
        
        let verificationRequest = RegistrationVerificationRequest(
            cred: RegistrationVerificationRequest.CredentialData(
                id: credentialIdBase64,
                rawId: credentialIdBase64,
                type: "public-key",
                response: RegistrationVerificationRequest.CredentialData.ResponseData(
                    clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
                    attestationObject: credential.rawAttestationObject?.base64URLEncodedString() ?? ""
                )
            ),
            challengeKey: challengeKey,
            username: username ?? "Anonymous" // Ensure anonymous users have a username
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        request.httpBody = try encoder.encode(verificationRequest)
        
        // Debug logging
        Log.passkey.debug("Registration verification request", metadata: [
            "credentialId": credential.credentialID.base64URLEncodedString(),
            "attestationObjectSize": credential.rawAttestationObject?.count ?? 0,
            "clientDataJSONSize": credential.rawClientDataJSON.count,
            "challengeKey": challengeKey
        ])
        
        #if DEBUG
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            Log.passkey.debug("Registration request JSON", metadata: ["body": jsonString])
        }
        #endif
        
        Log.network.info("Sending registration verification request")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.network.error("Invalid response type")
            throw PasskeyError.serverError
        }
        
        Log.network.info("Registration verification response", metadata: [
            "status": httpResponse.statusCode
        ])
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.network.error("Server verification error", metadata: [
                "status": httpResponse.statusCode,
                "response": errorString
            ])
            throw PasskeyError.serverError
        }
        
        let verificationResponse = try JSONDecoder().decode(RegistrationVerificationResponse.self, from: data)
        return (verificationResponse.verified, verificationResponse.username)
    }
    
    // MARK: - User Data Storage Methods
    
    /// Retrieves the backed-up encryption key for the current user
    func getBackedUpEncryptionKey() async throws -> String? {
        // This would need to know the current user's username and credential
        // For now, this is a placeholder - you'd call retrieveEncryptionKey with the right params
        return nil
    }
    
    func storeEncryptionKey(for username: String, credentialId: String? = nil, isAnonymous: Bool) async throws {
        // Get the device encryption key
        guard let encryptionKey = try? DeviceEncryptionService.shared.exportDeviceKey() else {
            Log.passkey.error("Failed to export device encryption key")
            throw PasskeyError.serverError
        }
        
        let identifier = username
        guard let url = URL(string: "\(baseURL)/api/users/\(identifier)/data") else {
            throw PasskeyError.invalidURL
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let userData = UserDataRequest(
            email: nil, // Anonymous users don't have email
            encryptedData: UserDataRequest.EncryptedData(
                encryptionKey: encryptionKey,
                keyFormat: "base64",
                createdAt: dateFormatter.string(from: Date()),
                deviceName: UIDevice.current.name
            ),
            authProof: "ios_app_\(UUID().uuidString)", // Placeholder since server doesn't validate yet
            credentialId: isAnonymous ? credentialId : nil
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(userData)
        
        Log.passkey.info("Storing encryption key for user", metadata: [
            "username": username,
            "isAnonymous": isAnonymous,
            "hasCredentialId": credentialId != nil
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.passkey.error("Failed to store encryption key", metadata: [
                "status": (response as? HTTPURLResponse)?.statusCode ?? -1,
                "error": errorString
            ])
            throw PasskeyError.serverError
        }
        
        let storeResponse = try JSONDecoder().decode(UserDataResponse.self, from: data)
        Log.passkey.success("Encryption key stored successfully", metadata: [
            "success": storeResponse.success,
            "hasEncryptedData": storeResponse.hasEncryptedData
        ])
    }
    
    func retrieveEncryptionKey(for username: String, credentialId: String? = nil, isAnonymous: Bool) async throws -> String? {
        let identifier = username
        var urlString = "\(baseURL)/api/users/\(identifier)/data"
        
        if isAnonymous, let credentialId = credentialId {
            urlString += "?credentialId=\(credentialId)"
        }
        
        guard let url = URL(string: urlString) else {
            throw PasskeyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        Log.passkey.info("Retrieving encryption key for user", metadata: [
            "username": username,
            "isAnonymous": isAnonymous
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            Log.passkey.error("Failed to retrieve encryption key", metadata: [
                "status": (response as? HTTPURLResponse)?.statusCode ?? -1
            ])
            return nil
        }
        
        let userData = try JSONDecoder().decode(UserDataGetResponse.self, from: data)
        
        if let encryptionKey = userData.encryptedData?.encryptionKey {
            Log.passkey.success("Encryption key retrieved successfully", metadata: [
                "deviceName": userData.encryptedData?.deviceName ?? "Unknown"
            ])
            return encryptionKey
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func performAuthorization(controller: ASAuthorizationController) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation
            Log.passkey.debug("Calling performRequests()")
            controller.performRequests()
            Log.passkey.debug("Passkey UI should be presenting")
        }
    }
    
    private var authorizationContinuation: CheckedContinuation<ASAuthorization, Error>?
    private var currentPresentationAnchor: ASPresentationAnchor?
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyAuthenticationService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            Log.passkey.success("Authorization completed")
            authorizationContinuation?.resume(returning: authorization)
            authorizationContinuation = nil
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            Log.passkey.error("Authorization failed", error: error)
            if let authError = error as? ASAuthorizationError {
                Log.passkey.debug("Authorization error details", metadata: [
                    "code": authError.code.rawValue,
                    "description": authError.localizedDescription
                ])
            }
            authorizationContinuation?.resume(throwing: error)
            authorizationContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyAuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Use the stored presentation anchor if available
        if let anchor = currentPresentationAnchor {
            Log.passkey.debug("Using provided presentation anchor")
            return anchor
        }
        
        // Fallback to finding the key window
        Log.passkey.warning("No presentation anchor provided, finding key window")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            Log.passkey.error("No key window found!")
            // Return first available window as fallback
            if let anyWindow = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first {
                return anyWindow
            }
            fatalError("No window available for passkey presentation")
        }
        Log.passkey.debug("Using key window for presentation")
        return window
    }
}

// MARK: - Error Types

enum PasskeyError: LocalizedError {
    case invalidURL
    case serverError
    case invalidCredentialType
    case noPasskeysFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error occurred"
        case .invalidCredentialType:
            return "Invalid credential type"
        case .noPasskeysFound:
            return "No passkeys found for this app"
        }
    }
}