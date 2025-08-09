import SwiftUI

/// Native sheet that collects the 6-digit OTP code from the user.
/// Sends the OTP and challengeId to proxy server's /striga/confirm-consent endpoint.
/// Returns the cardAuthToken for card rendering.
struct CardOTPConsentView: View {
    let userId: String
    let cardId: String
    let challengeId: String
    @Binding var isPresented: Bool
    let onSuccess: (String) -> Void // Returns authToken instead of CardModel
    
    init(userId: String, cardId: String, challengeId: String, isPresented: Binding<Bool>, onSuccess: @escaping (String) -> Void) {
        self.userId = userId
        self.cardId = cardId
        self.challengeId = challengeId
        self._isPresented = isPresented
        self.onSuccess = onSuccess
        
        print("📱 [CardOTPConsentView] OTP Sheet initialized")
        print("📱 [CardOTPConsentView] User ID: \(userId)")
        print("📱 [CardOTPConsentView] Card ID: \(cardId)")
        print("📱 [CardOTPConsentView] Challenge ID: \(challengeId)")
    }

    @State private var otpCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter the 6-digit code")
                    .font(.headline)
                
                #if DEBUG
                Text("Sandbox: Use 123456")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #endif

                TextField("123456", text: $otpCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 120)

                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 16) {
                    Button(action: submit) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Confirm")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(otpCode.count != 6 || isLoading)
                    
                    Button("Resend Code") {
                        resendCode()
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .navigationTitle("Verify")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }

    private func submit() {
        guard otpCode.count == 6 else {
            print("⚠️ [CardOTPConsentView] Invalid code length: \(otpCode.count)")
            return
        }
        errorMessage = nil
        isLoading = true
        
        print("🚀 [CardOTPConsentView] Step 2: User submitted OTP code")
        print("📱 [CardOTPConsentView] Code entered: \(otpCode)")

        Task {
            do {
                // Send OTP to proxy server's /striga/confirm-consent endpoint
                let proxyURL = "https://passkey.nuri.com/striga/confirm-consent"
                var request = URLRequest(url: URL(string: proxyURL)!)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let payload: [String: Any] = [
                    "userId": userId,
                    "challengeId": challengeId,
                    "verificationCode": otpCode
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                print("🚀 [CardOTPConsentView] Calling proxy server...")
                print("📱 [CardOTPConsentView] URL: \(proxyURL)")
                print("📱 [CardOTPConsentView] Method: POST")
                print("📱 [CardOTPConsentView] Payload:")
                print("📱 [CardOTPConsentView]   - userId: \(userId)")
                print("📱 [CardOTPConsentView]   - challengeId: \(challengeId)")
                print("📱 [CardOTPConsentView]   - verificationCode: \(otpCode)")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("📱 [CardOTPConsentView] Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ [CardOTPConsentView] SUCCESS: Proxy returned 200 OK")
                    
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let authToken = json?["cardAuthToken"] as? String else {
                        print("❌ [CardOTPConsentView] ERROR: No auth token in response")
                        print("📱 [CardOTPConsentView] Response body: \(String(data: data, encoding: .utf8) ?? "nil")")
                        throw NSError(domain: "CardOTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "No auth token in response"])
                    }
                    
                    print("✅ [CardOTPConsentView] Got auth token from proxy")
                    print("📱 [CardOTPConsentView] Auth token length: \(authToken.count)")
                    
                    await MainActor.run {
                        onSuccess(authToken)
                        isPresented = false
                    }
                } else {
                    // Parse error response from proxy
                    var errorMessage = "Verification failed"
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let error = json["error"] as? String {
                            errorMessage = error
                        } else if let message = json["message"] as? String {
                            errorMessage = message
                        }
                    } else {
                        errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    }
                    
                    print("❌ [CardOTPConsentView] ERROR: Proxy returned error status \(httpResponse.statusCode)")
                    print("📱 [CardOTPConsentView] Error message: \(errorMessage)")
                    print("📱 [CardOTPConsentView] Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                    
                    // Handle specific HTTP status codes as per proxy documentation
                    switch httpResponse.statusCode {
                    case 400:
                        // Missing or invalid parameters
                        errorMessage = "Invalid request. Please try again."
                    case 401, 403:
                        // Authentication issues with Striga
                        errorMessage = "Authentication failed. Please try again later."
                    case 500:
                        // Server error - likely invalid userId/challengeId
                        if errorMessage.contains("Invalid verification code") {
                            errorMessage = "Invalid code. Please check and try again."
                        } else if errorMessage.contains("expired") || errorMessage.contains("Challenge not found") {
                            errorMessage = "Code expired. Please request a new one."
                        } else {
                            errorMessage = "Server error. Please try again."
                        }
                    default:
                        // Keep the parsed error message
                        break
                    }
                    
                    throw NSError(domain: "CardOTP", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            } catch {
                print("❌ [CardOTPConsentView] EXCEPTION: \(error)")
                print("📱 [CardOTPConsentView] Error type: \(type(of: error))")
                print("📱 [CardOTPConsentView] Error details: \(error.localizedDescription)")
                
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func resendCode() {
        print("🚀 [CardOTPConsentView] User requested code resend")
        print("📱 [CardOTPConsentView] Challenge ID: \(challengeId)")
        
        Task {
            do {
                // Send resend request to proxy server
                let proxyURL = "https://passkey.nuri.com/striga/resend-consent-code"
                var request = URLRequest(url: URL(string: proxyURL)!)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let payload: [String: Any] = [
                    "userId": userId,
                    "challengeId": challengeId
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 200 {
                    print("[OTP] ✅ Code resent successfully")
                    await MainActor.run {
                        errorMessage = nil
                        // Show success message briefly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            errorMessage = "New code sent to your phone/email"
                        }
                    }
                } else {
                    var errorMsg = "Failed to resend code"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        errorMsg = error
                    }
                    print("[OTP] ❌ Failed to resend code: \(errorMsg)")
                    await MainActor.run {
                        errorMessage = errorMsg
                    }
                }
            } catch {
                print("[OTP] Error resending: \(error)")
            }
        }
    }
}
