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
    
    init(isPresented: Binding<Bool>, onSuccess: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.onSuccess = onSuccess
        
        print("[CardVerification] ========== INIT ==========")
        print("[CardVerification] View initialized")
        
        // Configure Striga for sandbox (development) if not already configured
        if striga.configuration == nil {
            striga.configuration = StrigaConfiguration(
                url: "https://www.sandbox.striga.com/api/",
                key: "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=",
                secret: "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE="
            )
            print("[CardVerification] Configured Striga for sandbox environment")
        } else {
            print("[CardVerification] Striga already configured")
        }
        print("[CardVerification] ==========================")
    }
    
    var body: some View {
        NavigationStack {
            UnifiedInputView(
                mode: .smsCode,
                inputText: $verificationCode,
                countryCode: .constant(""),
                showCountryPicker: .constant(false),
                countryName: "",
                isValid: verificationCode.count == 6,
                onNext: {
                    print("[CardVerification] onNext called from UnifiedInputView")
                    print("[CardVerification] Current code: \(verificationCode)")
                    // Auto-submits when 6 digits are entered
                    if verificationCode.count == 6 {
                        print("[CardVerification] Triggering verification from Next button")
                        Task {
                            await verifyCode()
                        }
                    } else {
                        print("[CardVerification] Code not 6 digits, ignoring Next button")
                    }
                },
                onCountryPicked: { _ in }
            )
            .onChange(of: verificationCode) { _, newValue in
                print("[CardVerification] Code changed: '\(newValue)' (length: \(newValue.count))")
                if newValue.count == 6 {
                    print("[CardVerification] Code is 6 digits, triggering verification")
                    Task {
                        await verifyCode()
                    }
                } else {
                    print("[CardVerification] Waiting for 6 digits (current: \(newValue.count))")
                }
            }
            .onAppear {
                print("[CardVerification] ========== VIEW APPEARED ==========")
                print("[CardVerification] Starting SMS verification process")
                sendVerificationCode()
            }
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                print("[CardVerification] Keyboard will show")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                print("[CardVerification] Keyboard will hide")
            }
        }
    }
    
    private func sendVerificationCode() {
        Task {
            print("[CardVerification] ========== SEND VERIFICATION CODE ==========")
            isLoading = true
            do {
                print("[CardVerification] Checking session data...")
                print("[CardVerification] Session userId: \(StrigaSession.shared.userId ?? "nil")")
                print("[CardVerification] Session cardId: \(StrigaSession.shared.cardId ?? "nil")")
                
                guard let userId = StrigaSession.shared.userId,
                      let cardId = StrigaSession.shared.cardId else {
                    print("[CardVerification] ❌ ERROR: Missing user or card ID")
                    print("[CardVerification] userId: \(StrigaSession.shared.userId ?? "nil")")
                    print("[CardVerification] cardId: \(StrigaSession.shared.cardId ?? "nil")")
                    errorMessage = "Missing user information"
                    isLoading = false
                    return
                }
                
                print("[CardVerification] Requesting consent...")
                print("[CardVerification] - userId: \(userId)")
                print("[CardVerification] - cardId: \(cardId)")
                
                let response = try await striga.requestConsent(.init(
                    userId: userId,
                    cardId: cardId
                ))
                
                challengeId = response.challengeId
                print("[CardVerification] ✅ SUCCESS: Consent requested")
                print("[CardVerification] - Challenge ID: \(response.challengeId)")
                print("[CardVerification] - Expires: \(response.dateExpires)")
                print("[CardVerification] SMS should be sent to user's phone now")
            } catch {
                print("[CardVerification] ❌ ERROR requesting consent:")
                print("[CardVerification] Error type: \(type(of: error))")
                print("[CardVerification] Error details: \(error)")
                print("[CardVerification] Error localized: \(error.localizedDescription)")
                errorMessage = "Failed to send verification code: \(error.localizedDescription)"
            }
            isLoading = false
            print("[CardVerification] ========================================")
        }
    }
    
    @MainActor
    private func verifyCode() async {
        print("[CardVerification] ========== VERIFY CODE ==========")
        print("[CardVerification] Starting verification with code: \(verificationCode)")
        
        isLoading = true
        errorMessage = ""
        
        do {
            print("[CardVerification] Checking required data...")
            print("[CardVerification] - userId: \(StrigaSession.shared.userId ?? "nil")")
            print("[CardVerification] - challengeId: \(challengeId ?? "nil")")
            print("[CardVerification] - code: \(verificationCode)")
            
            guard let userId = StrigaSession.shared.userId,
                  let challengeId = challengeId else {
                print("[CardVerification] ❌ ERROR: Missing required data")
                print("[CardVerification] - userId present: \(StrigaSession.shared.userId != nil)")
                print("[CardVerification] - challengeId present: \(challengeId != nil)")
                errorMessage = "Missing verification data"
                isLoading = false
                return
            }
            
            print("[CardVerification] Sending confirmation to Striga...")
            print("[CardVerification] - userId: \(userId)")
            print("[CardVerification] - challengeId: \(challengeId)")
            print("[CardVerification] - verificationCode: \(verificationCode)")
            
            let response = try await striga.confirmConsent(.init(
                userId: userId,
                challengeId: challengeId,
                verificationCode: verificationCode
            ))
            
            print("[CardVerification] ✅ SUCCESS: Consent confirmed!")
            print("[CardVerification] Auth token received: \(response.cardAuthToken.prefix(20))...")
            print("[CardVerification] Calling onSuccess callback")
            
            onSuccess(response.cardAuthToken)
            isPresented = false
            
            print("[CardVerification] View dismissed")
        } catch {
            print("[CardVerification] ❌ ERROR confirming consent:")
            print("[CardVerification] Error type: \(type(of: error))")
            print("[CardVerification] Error details: \(error)")
            
            if let validationError = error as? ValidationErrorResponse {
                print("[CardVerification] Validation error: \(validationError.message)")
                errorMessage = validationError.message
            } else {
                print("[CardVerification] Generic error")
                errorMessage = "Invalid code. Please try again."
            }
            
            print("[CardVerification] Clearing verification code")
            verificationCode = ""
        }
        
        isLoading = false
        print("[CardVerification] ========================================")
    }
}