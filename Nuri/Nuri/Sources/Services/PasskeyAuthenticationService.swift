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
        #if targetEnvironment(simulator)
        return "http://localhost:3000"
        #else
        // Production passkey server
        return "https://passkey.nuri.com"
        #endif
    }
    private let relyingPartyIdentifier = "nuri.com" // Using parent domain for passkeys
    
    private override init() {
        super.init()
        print("🔐 [PasskeyAuthenticationService] Service initialized")
        print("🌐 [PasskeyAuthenticationService] Base URL: \(baseURL)")
        print("🆔 [PasskeyAuthenticationService] Relying Party ID: \(relyingPartyIdentifier)")
    }
    
    // MARK: - Authentication Models
    
    struct AuthenticationOptionsResponse: Codable {
        let challenge: String
        let timeout: Int
        let rpId: String
        let userVerification: String
    }
    
    struct AuthenticationVerificationRequest: Codable {
        let cred: CredentialData
        
        struct CredentialData: Codable {
            let credentialId: String
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
    
    struct RegistrationOptionsResponse: Codable {
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
            let authenticatorAttachment: String
            let requireResidentKey: Bool
            let userVerification: String
        }
    }
    
    struct RegistrationVerificationRequest: Codable {
        let username: String?
        let cred: CredentialData
        let challengeKey: String
        
        struct CredentialData: Codable {
            let credentialId: String
            let publicKey: String
            let authenticatorData: String
            let clientDataJSON: String
            let attestationObject: String
        }
    }
    
    struct RegistrationVerificationResponse: Codable {
        let verified: Bool
        let username: String?
        let isAnonymous: Bool
    }
    
    // MARK: - Main Authentication Flow
    
    func authenticateWithPasskey(presentationAnchor: ASPresentationAnchor) async throws -> (verified: Bool, username: String?, isAnonymous: Bool) {
        print("\n🔐 [PasskeyAuthenticationService] Starting passkey authentication flow...")
        
        // Store the presentation anchor
        self.currentPresentationAnchor = presentationAnchor
        defer { self.currentPresentationAnchor = nil }
        
        // Step 1: Get authentication options
        print("📡 [PasskeyAuthenticationService] Step 1: Fetching authentication options...")
        let authOptions = try await fetchAuthenticationOptions()
        print("✅ [PasskeyAuthenticationService] Received auth options: challenge length = \(authOptions.challenge.count)")
        
        // Step 2: Create credential assertion request
        print("🔨 [PasskeyAuthenticationService] Step 2: Creating credential assertion request...")
        let challenge = Data(base64URLEncoded: authOptions.challenge) ?? Data()
        print("📏 [PasskeyAuthenticationService] Challenge data size: \(challenge.count) bytes")
        
        // Use the rpId from the server response
        let rpId = authOptions.rpId
        print("🔐 [PasskeyAuthenticationService] Using server's rpId: \(rpId)")
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        let assertionRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge)
        print("✅ [PasskeyAuthenticationService] Assertion request created")
        
        // Step 3: Perform authorization
        print("🎯 [PasskeyAuthenticationService] Step 3: Presenting passkey UI...")
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        authController.delegate = self
        authController.presentationContextProvider = self
        
        do {
            let authorization = try await performAuthorization(controller: authController)
            
            print("🎉 [PasskeyAuthenticationService] User selected a credential")
            if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                print("📝 [PasskeyAuthenticationService] Credential ID: \(credential.credentialID.base64URLEncodedString())")
                print("👤 [PasskeyAuthenticationService] User handle: \(credential.userID.base64URLEncodedString())")
                
                // Step 4: Verify with server
                print("📡 [PasskeyAuthenticationService] Step 4: Verifying with server...")
                return try await verifyAuthentication(credential: credential)
            } else {
                print("❌ [PasskeyAuthenticationService] Invalid credential type received")
                throw PasskeyError.invalidCredentialType
            }
        } catch {
            print("❌ [PasskeyAuthenticationService] Authorization failed: \(error)")
            // Check if error is "no credentials found"
            if let authError = error as? ASAuthorizationError {
                print("🔍 [PasskeyAuthenticationService] ASAuthorizationError code: \(authError.code.rawValue)")
                if authError.code == .canceled {
                    print("🚫 [PasskeyAuthenticationService] User canceled the operation")
                } else if authError.code == .unknown {
                    print("❓ [PasskeyAuthenticationService] Unknown error - likely no passkeys")
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
        print("🔐 [PasskeyAuthenticationService] Using server's rpId for registration: \(rpId)")
        
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
            return try await verifyRegistration(credential: credential, username: username, challengeKey: regOptions.challengeKey)
        } else {
            throw PasskeyError.invalidCredentialType
        }
    }
    
    // MARK: - API Methods
    
    private func fetchAuthenticationOptions() async throws -> AuthenticationOptionsResponse {
        let endpoint = "\(baseURL)/generate-authentication-options"
        print("📡 [PasskeyAuthenticationService] Calling: GET \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("❌ [PasskeyAuthenticationService] Invalid URL: \(endpoint)")
            throw PasskeyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🚀 [PasskeyAuthenticationService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [PasskeyAuthenticationService] Invalid response type")
            throw PasskeyError.serverError
        }
        
        print("📦 [PasskeyAuthenticationService] Response status: \(httpResponse.statusCode)")
        
        if !(200...299).contains(httpResponse.statusCode) {
            print("❌ [PasskeyAuthenticationService] Server error: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("📄 [PasskeyAuthenticationService] Error body: \(errorString)")
            }
            throw PasskeyError.serverError
        }
        
        print("✅ [PasskeyAuthenticationService] Successfully received auth options")
        let authOptions = try JSONDecoder().decode(AuthenticationOptionsResponse.self, from: data)
        print("📋 [PasskeyAuthenticationService] Server rpId: \(authOptions.rpId)")
        return authOptions
    }
    
    private func verifyAuthentication(credential: ASAuthorizationPlatformPublicKeyCredentialAssertion) async throws -> (verified: Bool, username: String?, isAnonymous: Bool) {
        let endpoint = "\(baseURL)/verify-authentication"
        print("📡 [PasskeyAuthenticationService] Calling: POST \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("❌ [PasskeyAuthenticationService] Invalid URL: \(endpoint)")
            throw PasskeyError.invalidURL
        }
        
        let verificationRequest = AuthenticationVerificationRequest(
            cred: AuthenticationVerificationRequest.CredentialData(
                credentialId: credential.credentialID.base64URLEncodedString(),
                authenticatorData: credential.rawAuthenticatorData.base64URLEncodedString(),
                clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
                signature: credential.signature.base64URLEncodedString(),
                userHandle: credential.userID.isEmpty ? nil : credential.userID.base64URLEncodedString()
            )
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(verificationRequest)
        
        print("📤 [PasskeyAuthenticationService] Sending verification request...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PasskeyError.serverError
        }
        
        let verificationResponse = try JSONDecoder().decode(AuthenticationVerificationResponse.self, from: data)
        print("✅ [PasskeyAuthenticationService] Verification result: verified=\(verificationResponse.verified), username=\(verificationResponse.username ?? "none"), isAnonymous=\(verificationResponse.isAnonymous)")
        return (verificationResponse.verified, verificationResponse.username, verificationResponse.isAnonymous)
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
        
        let verificationRequest = RegistrationVerificationRequest(
            username: username,
            cred: RegistrationVerificationRequest.CredentialData(
                credentialId: credential.credentialID.base64URLEncodedString(),
                publicKey: "", // Not directly available in iOS, included in attestationObject
                authenticatorData: "", // Not directly available in iOS, included in attestationObject
                clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
                attestationObject: credential.rawAttestationObject?.base64URLEncodedString() ?? ""
            ),
            challengeKey: challengeKey
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(verificationRequest)
        
        print("📤 [PasskeyAuthenticationService] Sending verification request...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PasskeyError.serverError
        }
        
        let verificationResponse = try JSONDecoder().decode(RegistrationVerificationResponse.self, from: data)
        return (verificationResponse.verified, verificationResponse.username)
    }
    
    // MARK: - Helper Methods
    
    private func performAuthorization(controller: ASAuthorizationController) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation
            print("🚀 [PasskeyAuthenticationService] Calling performRequests()...")
            controller.performRequests()
            print("📱 [PasskeyAuthenticationService] Passkey UI should be presenting now...")
        }
    }
    
    private var authorizationContinuation: CheckedContinuation<ASAuthorization, Error>?
    private var currentPresentationAnchor: ASPresentationAnchor?
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyAuthenticationService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            print("✅ [PasskeyAuthenticationService] Authorization succeeded")
            authorizationContinuation?.resume(returning: authorization)
            authorizationContinuation = nil
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            print("❌ [PasskeyAuthenticationService] Authorization failed with error: \(error)")
            if let authError = error as? ASAuthorizationError {
                print("🔍 [PasskeyAuthenticationService] Error code: \(authError.code.rawValue)")
                print("📝 [PasskeyAuthenticationService] Error description: \(authError.localizedDescription)")
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
            print("✅ [PasskeyAuthenticationService] Using provided presentation anchor")
            return anchor
        }
        
        // Fallback to finding the key window
        print("⚠️ [PasskeyAuthenticationService] No presentation anchor provided, finding key window")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            print("❌ [PasskeyAuthenticationService] No key window found!")
            // Return first available window as fallback
            if let anyWindow = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first {
                return anyWindow
            }
            fatalError("No window available for passkey presentation")
        }
        print("✅ [PasskeyAuthenticationService] Using key window for passkey presentation")
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