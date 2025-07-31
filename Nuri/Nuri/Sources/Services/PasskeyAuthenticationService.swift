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
            let type: String
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
        let authenticatorType: String? // Add this to indicate security key
        
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
        
        // Support both platform (built-in) and cross-platform (hardware key) authenticators
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)
        
        // Also create a security key provider for hardware keys like YubiKey
        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let securityKeyRequest = securityKeyProvider.createCredentialAssertionRequest(challenge: challenge)
        
        // Override userVerification for security keys to avoid PIN prompt during authentication
        // This matches our registration behavior
        securityKeyRequest.userVerificationPreference = .discouraged
        
        Log.passkey.success("Assertion requests created for both platform and security keys", metadata: [
            "challengeSize": challenge.count,
            "rpId": rpId,
            "securityKeyUserVerification": "discouraged",
            "serverUserVerification": authOptions.userVerification
        ])
        
        // Step 3: Perform authorization with both request types
        Log.passkey.info("Step 3: Presenting passkey UI (supports both platform and hardware keys)")
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest, securityKeyRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        
        Log.passkey.debug("🔍 Authentication controller setup", metadata: [
            "requestCount": "2",
            "platformRequest": "included",
            "securityKeyRequest": "included",
            "rpId": rpId
        ])
        
        do {
            let authorization = try await performAuthorization(controller: authController)
            
            // Handle both platform (built-in) and security key credentials
            if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                Log.passkey.success("User selected platform credential (built-in)", metadata: [
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
            } else if let credential = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
                Log.passkey.success("User selected security key credential (hardware key)", metadata: [
                    "credentialId": credential.credentialID.base64URLEncodedString(),
                    "userHandle": credential.userID.base64URLEncodedString(),
                    "authenticatorDataSize": credential.rawAuthenticatorData.count,
                    "clientDataJSONSize": credential.rawClientDataJSON.count,
                    "signatureSize": credential.signature.count
                ])
                
                // Step 4: Verify with server (using security key credential)
                Log.passkey.info("Step 4: Verifying security key with server")
                let result = try await verifySecurityKeyAuthentication(credential: credential)
                
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
    
    // Add hardware security key only (no platform passkey)
    func addSecurityKey(username: String? = nil, presentationAnchor: ASPresentationAnchor) async throws -> (verified: Bool, username: String?) {
        Log.passkey.info("===== ADD SECURITY KEY STARTED =====")
        Log.passkey.info("Starting security key registration", metadata: [
            "username": username ?? "anonymous",
            "hasUsername": username != nil
        ])
        
        // Store the presentation anchor
        self.currentPresentationAnchor = presentationAnchor
        defer { 
            Log.passkey.info("Cleaning up presentation anchor")
            self.currentPresentationAnchor = nil 
        }
        
        // Step 1: Get registration options
        Log.passkey.info("Step 1: Fetching registration options from server")
        let regOptions = try await fetchRegistrationOptions(username: username)
        
        // Debug: Log exact server requirements
        Log.passkey.info("🔍 DEBUG: Server authenticator selection", metadata: [
            "requireResidentKey": regOptions.authenticatorSelection.requireResidentKey,
            "residentKey": regOptions.authenticatorSelection.residentKey ?? "none",
            "userVerification": regOptions.authenticatorSelection.userVerification,
            "authenticatorAttachment": regOptions.authenticatorSelection.authenticatorAttachment ?? "none"
        ])
        
        Log.passkey.success("Registration options received", metadata: [
            "challenge": regOptions.challenge.prefix(20) + "...",
            "rpId": regOptions.rp.id,
            "userName": regOptions.user.name,
            "userDisplayName": regOptions.user.displayName,
            "requireResidentKey": regOptions.authenticatorSelection.requireResidentKey,
            "residentKey": regOptions.authenticatorSelection.residentKey ?? "none",
            "userVerification": regOptions.authenticatorSelection.userVerification
        ])
        
        // Step 2: Create credential registration request
        Log.passkey.info("Step 2: Creating security key registration request")
        let challenge = Data(base64URLEncoded: regOptions.challenge) ?? Data()
        let userID = Data(regOptions.user.id.utf8)
        
        Log.passkey.debug("Challenge and user data", metadata: [
            "challengeSize": challenge.count,
            "userIDSize": userID.count,
            "userIDString": regOptions.user.id
        ])
        
        // Use the rpId from the server response
        let rpId = regOptions.rp.id
        Log.passkey.info("Using server's rpId for security key registration", metadata: ["rpId": rpId])
        
        // ONLY create security key request - no platform request
        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let securityKeyRequest = securityKeyProvider.createCredentialRegistrationRequest(
            challenge: challenge,
            displayName: regOptions.user.displayName,
            name: regOptions.user.name,
            userID: userID
        )
        
        // IMPORTANT: Security keys require specifying supported algorithms
        // Set the supported credential algorithms (required for security keys)
        // ES256 is the most widely supported algorithm for security keys
        securityKeyRequest.credentialParameters = [
            ASAuthorizationPublicKeyCredentialParameters(
                algorithm: ASCOSEAlgorithmIdentifier.ES256 // ECDSA with SHA-256
            )
        ]
        
        // IMPORTANT: For security keys (YubiKey), we override to discouraged to avoid PIN setup
        // Even when server sends "preferred", iOS will prompt for PIN setup on YubiKey
        // By using "discouraged", the YubiKey works with just a touch (no PIN required)
        securityKeyRequest.residentKeyPreference = .discouraged
        securityKeyRequest.userVerificationPreference = .discouraged
        
        // Note: Platform authenticators (Face ID) still use server's requirements
        // This override only affects security keys to match expected UX
        
        Log.passkey.info("Overriding server requirements for security key", metadata: [
            "serverResidentKey": regOptions.authenticatorSelection.residentKey ?? "none",
            "serverUserVerification": regOptions.authenticatorSelection.userVerification,
            "actualResidentKey": "discouraged",
            "actualUserVerification": "discouraged",
            "reason": "Avoid PIN prompt on YubiKey"
        ])
        
        // Step 3: Perform authorization with ONLY security key
        let authController = ASAuthorizationController(authorizationRequests: [securityKeyRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        
        // Determine the actual preferences for logging
        let residentKeyString: String
        if securityKeyRequest.residentKeyPreference == .discouraged {
            residentKeyString = "discouraged"
        } else if securityKeyRequest.residentKeyPreference == .preferred {
            residentKeyString = "preferred"
        } else if securityKeyRequest.residentKeyPreference == .required {
            residentKeyString = "required"
        } else {
            residentKeyString = "unknown"
        }
        
        let userVerificationString: String
        if securityKeyRequest.userVerificationPreference == .discouraged {
            userVerificationString = "discouraged"
        } else if securityKeyRequest.userVerificationPreference == .preferred {
            userVerificationString = "preferred"
        } else if securityKeyRequest.userVerificationPreference == .required {
            userVerificationString = "required"
        } else {
            userVerificationString = "unknown"
        }
        
        Log.passkey.info("Step 3: Presenting security key registration UI", metadata: [
            "algorithm": "ES256",
            "residentKey": residentKeyString,
            "userVerification": userVerificationString,
            "transports": "NFC, USB",
            "note": "PIN setup will be required until server accepts discouraged"
        ])
        
        Log.passkey.info("About to call performAuthorization - UI should appear now")
        
        let authorization: ASAuthorization
        do {
            Log.passkey.info("Calling performAuthorization...")
            authorization = try await performAuthorization(controller: authController)
            Log.passkey.success("performAuthorization completed successfully")
        } catch {
            Log.passkey.error("performAuthorization failed", error: error)
            throw error
        }
        
        Log.passkey.info("Checking credential type", metadata: [
            "credentialType": String(describing: type(of: authorization.credential))
        ])
        
        if let credential = authorization.credential as? ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
            Log.passkey.success("User registered with security key", metadata: [
                "credentialId": credential.credentialID.base64URLEncodedString(),
                "attestationObjectSize": credential.rawAttestationObject?.count ?? 0,
                "clientDataJSONSize": credential.rawClientDataJSON.count
            ])
            
            // Step 4: Verify with server
            Log.passkey.info("Step 4: Starting server verification", metadata: [
                "username": username ?? "Anonymous",
                "challengeKey": regOptions.challengeKey
            ])
            
            let result = try await verifySecurityKeyRegistration(credential: credential, username: username, challengeKey: regOptions.challengeKey)
            
            Log.passkey.success("Server verification completed", metadata: [
                "verified": result.verified,
                "returnedUsername": result.username ?? "none"
            ])
            
            // Step 5: Store encryption key if registration successful
            if result.verified, let username = result.username {
                Log.passkey.info("Step 5: Storing encryption key with security key", metadata: [
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
                    Log.passkey.success("Encryption key stored successfully with security key")
                } catch {
                    Log.passkey.error("Failed to store encryption key", error: error)
                    // Don't fail the registration if key storage fails
                }
            }
            
            return result
        } else {
            Log.passkey.error("Expected security key credential but got something else")
            throw PasskeyError.invalidCredentialType
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
        
        // For registration, only use platform provider to avoid confusion
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
        
        // Log the actual credential type received
        Log.passkey.info("Received credential type", metadata: [
            "type": String(describing: type(of: authorization.credential)),
            "expectedRegistration": "true"
        ])
        
        // Check if we received an assertion instead of registration
        if authorization.credential is ASAuthorizationPlatformPublicKeyCredentialAssertion || 
           authorization.credential is ASAuthorizationSecurityKeyPublicKeyCredentialAssertion {
            Log.passkey.error("Received assertion credential instead of registration credential")
            throw PasskeyError.registrationReturnedAuthentication
        }
        
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
    
    private func verifySecurityKeyAuthentication(credential: ASAuthorizationSecurityKeyPublicKeyCredentialAssertion) async throws -> (verified: Bool, username: String?, isAnonymous: Bool) {
        // Security key authentication uses the same verification endpoint
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
                type: "public-key",
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
        
        Log.passkey.debug("Security key verification request", metadata: [
            "credentialId": credentialIdBase64,
            "authenticatorType": "securityKey",
            "userHandle": credential.userID.base64URLEncodedString(),
            "endpoint": endpoint
        ])
        
        #if DEBUG
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            Log.passkey.debug("Security key auth request JSON", metadata: ["body": jsonString])
        }
        #endif
        
        Log.network.info("Sending security key verification request to: \(endpoint)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Log.network.error("Invalid response type")
            throw PasskeyError.serverError
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.network.error("Server verification error", metadata: [
                "status": httpResponse.statusCode,
                "response": errorString
            ])
            throw PasskeyError.serverError
        }
        
        let verificationResponse = try JSONDecoder().decode(AuthenticationVerificationResponse.self, from: data)
        Log.passkey.success("Security key verification successful", metadata: [
            "verified": verificationResponse.verified,
            "username": verificationResponse.username ?? "anonymous",
            "isAnonymous": verificationResponse.isAnonymous
        ])
        return (verificationResponse.verified, verificationResponse.username, verificationResponse.isAnonymous)
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
                type: "public-key",
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
    
    private func verifySecurityKeyRegistration(credential: ASAuthorizationSecurityKeyPublicKeyCredentialRegistration, username: String?, challengeKey: String) async throws -> (verified: Bool, username: String?) {
        // Security key registration uses the same verification endpoint
        guard let url = URL(string: "\(baseURL)/verify-registration") else {
            throw PasskeyError.invalidURL
        }
        
        let credentialIdBase64 = credential.credentialID.base64URLEncodedString()
        
        // For anonymous users, match the working platform passkey implementation
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
            username: username ?? "Anonymous", // Match platform passkey behavior - send "Anonymous" for anonymous users
            authenticatorType: "cross-platform" // Indicate this is a security key, not platform authenticator
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        request.httpBody = try encoder.encode(verificationRequest)
        
        Log.passkey.debug("Security key registration verification request", metadata: [
            "credentialId": credential.credentialID.base64URLEncodedString(),
            "attestationObjectSize": credential.rawAttestationObject?.count ?? 0,
            "authenticatorType": "securityKey",
            "challengeKey": challengeKey,
            "username": username ?? "Anonymous",
            "actualUsername": verificationRequest.username ?? "nil"
        ])
        
        #if DEBUG
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            Log.passkey.debug("Request JSON for security key", metadata: ["body": jsonString])
        }
        #endif
        
        Log.network.info("Sending security key registration verification request to: \(url.absoluteString)")
        
        // Add timeout to prevent hanging
        var urlRequest = request
        urlRequest.timeoutInterval = 30.0 // 30 second timeout
        
        Log.network.debug("Request timeout set to 30 seconds")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyError.serverError
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.network.error("Server verification error", metadata: [
                "status": httpResponse.statusCode,
                "response": errorString
            ])
            throw PasskeyError.serverError
        }
        
        let verificationResponse = try JSONDecoder().decode(RegistrationVerificationResponse.self, from: data)
        Log.passkey.success("Security key registration successful", metadata: [
            "verified": verificationResponse.verified,
            "username": verificationResponse.username ?? "anonymous"
        ])
        return (verificationResponse.verified, verificationResponse.username)
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
            username: username ?? "Anonymous", // Ensure anonymous users have a username
            authenticatorType: "platform" // Indicate this is a platform authenticator (Face ID/Touch ID)
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
    
    // MARK: - Get User Passkeys
    
    struct UserPasskeysResponse: Codable {
        let passkeys: [PasskeyInfo]
        
        struct PasskeyInfo: Codable {
            let credentialId: String
            let deviceName: String?
            let lastUsed: String?
            let createdAt: String
        }
    }
    
    func getUserPasskeys(for username: String) async throws -> [UserPasskeysResponse.PasskeyInfo] {
        let identifier = username
        guard let url = URL(string: "\(baseURL)/api/users/\(identifier)/passkeys") else {
            throw PasskeyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        Log.passkey.info("Fetching passkeys for user", metadata: ["username": username])
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                Log.passkey.error("Failed to fetch passkeys", metadata: [
                    "status": (response as? HTTPURLResponse)?.statusCode ?? -1
                ])
                return []
            }
            
            let passkeysResponse = try JSONDecoder().decode(UserPasskeysResponse.self, from: data)
            Log.passkey.success("Fetched passkeys", metadata: [
                "count": passkeysResponse.passkeys.count
            ])
            return passkeysResponse.passkeys
        } catch {
            Log.passkey.error("Error fetching passkeys", error: error)
            // Return empty array if the endpoint doesn't exist yet
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func performAuthorization(controller: ASAuthorizationController) async throws -> ASAuthorization {
        Log.passkey.info("performAuthorization started")
        return try await withCheckedThrowingContinuation { continuation in
            Log.passkey.info("Setting up continuation")
            self.authorizationContinuation = continuation
            Log.passkey.debug("Calling performRequests() - this will trigger the UI")
            controller.performRequests()
            Log.passkey.debug("performRequests() called - waiting for user interaction")
        }
    }
    
    private var authorizationContinuation: CheckedContinuation<ASAuthorization, Error>?
    private var currentPresentationAnchor: ASPresentationAnchor?
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyAuthenticationService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🟢 [DELEGATE] Authorization completed successfully")
        Task { @MainActor in
            Log.passkey.success("===== AUTHORIZATION DELEGATE: SUCCESS =====")
            Log.passkey.info("Authorization completed", metadata: [
                "credentialType": String(describing: type(of: authorization.credential))
            ])
            
            if let continuation = authorizationContinuation {
                Log.passkey.info("Resuming continuation with success")
                continuation.resume(returning: authorization)
                authorizationContinuation = nil
            } else {
                Log.passkey.error("WARNING: No continuation found to resume!")
            }
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("🔴 [DELEGATE] Authorization failed with error: \(error)")
        Task { @MainActor in
            Log.passkey.error("===== AUTHORIZATION DELEGATE: ERROR =====")
            Log.passkey.error("Authorization failed", error: error)
            
            if let authError = error as? ASAuthorizationError {
                Log.passkey.debug("Authorization error details", metadata: [
                    "code": authError.code.rawValue,
                    "description": authError.localizedDescription
                ])
                
                // Log specific error types
                switch authError.code {
                case .canceled:
                    Log.passkey.info("User canceled the operation")
                case .failed:
                    Log.passkey.error("Operation failed")
                case .invalidResponse:
                    Log.passkey.error("Invalid response from authenticator")
                case .notHandled:
                    Log.passkey.error("Request not handled")
                case .notInteractive:
                    Log.passkey.error("Request requires user interaction")
                case .unknown:
                    Log.passkey.error("Unknown error - possibly no credentials")
                @unknown default:
                    Log.passkey.error("Unexpected error code")
                }
            }
            
            if let continuation = authorizationContinuation {
                Log.passkey.info("Resuming continuation with error")
                continuation.resume(throwing: error)
                authorizationContinuation = nil
            } else {
                Log.passkey.error("WARNING: No continuation found to resume with error!")
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyAuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        print("🪟 [PRESENTATION] presentationAnchor called")
        Log.passkey.info("===== PRESENTATION ANCHOR REQUESTED =====")
        
        // Use the stored presentation anchor if available
        if let anchor = currentPresentationAnchor {
            Log.passkey.success("Using provided presentation anchor", metadata: [
                "hasAnchor": "true",
                "anchorType": String(describing: type(of: anchor))
            ])
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
                Log.passkey.warning("Using fallback window")
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
    case registrationReturnedAuthentication
    
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
        case .registrationReturnedAuthentication:
            return "System returned authentication instead of registration. Please try again."
        }
    }
}