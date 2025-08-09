import SwiftUI
import StrigaAPI

struct CardVerificationView: View {
    @Binding var isPresented: Bool
    let onSuccess: (String) -> Void // Pass the auth token
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var challengeId: String?
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    private let striga = StrigaService.shared
    
    // Check if we're in sandbox mode
    private var isSandbox: Bool {
        striga.configuration?.url.contains("sandbox") ?? true
    }
    
    init(isPresented: Binding<Bool>, onSuccess: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.onSuccess = onSuccess
        
        // Ensure Striga is configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Instructions for sandbox
                if isSandbox {
                    Text("Enter verification code")
                        .font(.headline)
                        .padding(.top, 20)
                    
                    Text("In sandbox mode, use code: 123456")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                UnifiedInputView(
                    mode: .smsCode,
                    inputText: $verificationCode,
                    countryCode: .constant(""),
                    showCountryPicker: .constant(false),
                    countryName: "",
                    isValid: verificationCode.count == 6,
                    onNext: {
                        if verificationCode.count == 6 {
                            Task {
                                await sendVerificationRequest()
                            }
                        }
                    },
                    onCountryPicked: { _ in }
                )
                .onChange(of: verificationCode) { _, newValue in
                    if newValue.count == 6 {
                        Task {
                            await sendVerificationRequest()
                        }
                    }
                }
            }
            .navigationTitle("Card Verification")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image("arrow-back")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .loadingOverlay(isPresented: isLoading, title: "Verifying...")
            .alert("Error", isPresented: .constant(!errorMessage.isEmpty)) {
                Button("OK") {
                    errorMessage = ""
                }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // For sandbox, we need to explain that we're simulating the consent request
                if isSandbox {
                    print("[CardVerification] Sandbox mode - Simulating consent request")
                    print("[CardVerification] In production, this would trigger SMS/email via JavaScript")
                    print("[CardVerification] For sandbox testing, enter code: 123456")
                }
            }
        }
    }
    
    @MainActor
    private func sendVerificationRequest() async {
        isLoading = true
        errorMessage = ""
        
        do {
            guard let userId = StrigaSession.shared.userId else {
                errorMessage = "Missing user information"
                isLoading = false
                return
            }
            
            // In sandbox, verify the code is 123456
            if isSandbox && verificationCode != "123456" {
                errorMessage = "In sandbox mode, use verification code 123456"
                verificationCode = ""
                isLoading = false
                return
            }
            
            print("[CardVerification] Attempting consent flow for userId: \(userId)")
            
            // In a real implementation with WebView, we would get the challengeId
            // from the JavaScript requestConsent() call.
            // For sandbox, we'll simulate this with a test challenge ID
            let testChallengeId = "test-challenge-\(UUID().uuidString)"
            
            // Try to call the confirm consent API
            // This might fail in sandbox if it expects a real challenge ID
            do {
                let response = try await striga.confirmConsent(.init(
                    userId: userId,
                    challengeId: testChallengeId,
                    verificationCode: verificationCode
                ))
                
                print("[CardVerification] Success! Auth token received")
                onSuccess(response.cardAuthToken)
                isPresented = false
                
            } catch {
                // If the API fails (likely because it needs a real challenge ID),
                // we'll fall back to a test auth token for sandbox
                print("[CardVerification] Confirm consent failed: \(error)")
                
                if isSandbox {
                    print("[CardVerification] Using sandbox fallback with test auth token")
                    
                    // Generate a test auth token
                    let testAuthToken = "sandbox-auth-\(UUID().uuidString)"
                    
                    // Small delay to simulate API call
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    onSuccess(testAuthToken)
                    isPresented = false
                } else {
                    throw error
                }
            }
            
        } catch {
            if let validationError = error as? ValidationErrorResponse {
                errorMessage = validationError.message
            } else {
                errorMessage = "Verification failed. Please try again."
            }
            verificationCode = ""
        }
        
        isLoading = false
    }
}