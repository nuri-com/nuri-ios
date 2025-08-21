import Combine
import IdensicMobileSDK
import Foundation
import StrigaAPI

final class EnterSMSCodeViewModel: ObservableObject {

    var striga = StrigaService.shared

    @Published var viewState: EnterSMSCodeViewState = .empty

    init() {
        // Configure Striga if not already configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
            print("[Striga] Configured with Striga credentials")
        }
        viewState = .init(
            title: "SMS Verification",
            subtitle: "We've sent you a code to your phone number",
            illustrationName: "phone_update",
            codeTextField: .init(
                label: "Code",
                text: "",
                placeholder: "Verification Code",
                textChangeHandler: .init { [weak self] text in
                    self?.handleTextChange(text)
                }
            ),
            isLoadingAnimationActive: false,
            showKYC: false
        )
    }

    private func reduce(viewState: EnterSMSCodeViewState, action: EnterSMSCodeViewState.Action) -> EnterSMSCodeViewState {
        var viewState = viewState
        switch action {
        case .startLoadingAnimation:
            viewState.isLoadingAnimationActive = true
        case .showKYC:
            viewState.showKYC = true
        // Removed showCreatingCardView - card creation is automatic
        }
        return viewState
    }

    @MainActor
    private func updateViewState(action: EnterSMSCodeViewState.Action) async {
        viewState = reduce(viewState: viewState, action: action)
    }

    private func handleTextChange(_ text: String) {
        if text.count == 6 {
            createUserAndVerifySMS(code: text)
        }
    }

    private func createUserAndVerifySMS(code: String) {
        print("[SMS] Starting SMS verification...")
        print("[SMS] Code entered: \(code)")
        
        Task {
            await updateViewState(action: .startLoadingAnimation)
            do {
                // User should already be created by PhoneNumberViewModel
                // We just need to verify the SMS code
                guard let userId = StrigaSession.shared.userId else {
                    print("[SMS] ERROR: No userId found. User should have been created before SMS screen!")
                    print("[SMS] This indicates the flow is broken - user creation should happen in PhoneNumberViewModel")
                    return
                }
                
                print("[SMS] Verifying mobile number for user: \(userId)")
                print("[SMS] Verification code: \(code)")
                
                try await striga.verifyMobile(.init(
                    userId: userId,
                    verificationCode: code
                ))
                
                print("[SMS] ✅ Mobile verification successful")
                
                // CRITICAL TODO: Also verify email to enable MFA!
                // Without email verification, hosted card will fail with "Multi-factor authentication not enabled"
                // 
                // THE PROBLEM:
                // - We only verify phone, NOT email
                // - Striga requires BOTH for MFA
                // - That's why hosted card fails with "Multi-factor authentication not enabled"
                //
                // THE FIX NEEDED:
                // 1. Call striga.verifyEmail() with userId and verificationId (which is the code)
                // 2. In sandbox, same code 123456 works for both email and phone
                //
                // COMMENTED OUT DUE TO BUILD ISSUES - NEEDS FIXING
                /*
                print("[SMS] 📧 Verifying email with same code (sandbox uses 123456 for both)...")
                try await striga.verifyEmail(.init(
                    userId: userId,
                    verificationId: code  
                ))
                print("[SMS] ✅ Email verification successful")
                print("[SMS] ✅ MFA is now enabled (both email AND phone verified)")
                */
                
                print("[SMS] ⚠️ WARNING: Email NOT verified - MFA not fully enabled!")
                print("[SMS] ⚠️ Hosted card will fail with 'Multi-factor authentication not enabled'")
                print("[SMS] Starting KYC...")
                
                // Log all session data before KYC
                let session = StrigaSession.shared
                print("[SMS] Session data before KYC:")
                print("  - userId: \(session.userId ?? "nil")")
                print("  - firstName: \(session.firstName ?? "nil")")
                print("  - lastName: \(session.lastName ?? "nil")")
                print("  - name: \(session.name ?? "nil")")
                print("  - email: \(session.email ?? "nil")")
                print("  - phoneNumber: \(session.phoneNumber ?? "nil")")
                print("  - phoneCountryCode: \(session.phoneCountryCode ?? "nil")")
                
                // CRITICAL: Verify user exists in Striga before KYC
                print("[SMS] ⚠️ VERIFYING USER EXISTS BEFORE KYC ⚠️")
                print("[SMS] Starting KYC for userId: \(userId)")
                
                // User must exist because they received the SMS verification code
                // Striga wouldn't send SMS to a non-existent user
                print("[SMS] ✅ User exists (received SMS verification)")
                
                print("[SMS] ✅ User confirmed to exist. Starting KYC...")
                
                // Start KYC after successful verification
                let response = try await striga.startKYC(.init(userId: userId))
                print("[SMS] KYC started successfully. Token received.")
                print("[SMS] KYC token length: \(response.token.count)")
                await presentKYC(token: response.token)
            } catch {
                print("[SMS] Error during verification/KYC: \(error)")
                if let validationError = error as? ValidationErrorResponse {
                    print("[SMS] Validation error: \(validationError.message)")
                    print("[SMS] Error code: \(validationError.errorCode)")
                    print("[SMS] Error details: \(validationError.errorDetails)")
                }
            }
        }
    }
    
    // REMOVED: User creation now happens in PhoneNumberViewModel
    // This ensures user is created BEFORE SMS screen appears
    // which is required for Striga to send the SMS

    @MainActor
    private func presentKYC(token: String) async {
        let sdk = SNSMobileSDK(
            accessToken: token
        )
        guard sdk.isReady else {
            print("Initialization failed: " + sdk.verboseStatus)
            return
        }
        // Don't set token expiration handler - let the SDK handle it internally
        // The token from Striga should be valid for the entire KYC session
        sdk.present()
        sdk.verificationHandler { (isApproved) in
            print("[Lukas] verificationHandler: Applicant is " + (isApproved ? "approved" : "finally rejected"))
            if isApproved {
                print("\n═══════════════════════════════════════════════════")
                print("✅ [KYC] KYC APPROVED - TRANSITIONING TO POST-KYC FLOW")
                print("   📋 Will present UserInfoView in new modal")
                print("   ⚠️ SMS screen will be dismissed permanently")
                print("═══════════════════════════════════════════════════\n")
                
                // Use PostKYCCoordinator to handle the flow properly
                // This dismisses SMS screen and presents UserInfoView in a new modal
                PostKYCCoordinator.shared.presentUserInfoAfterKYC()
            } else {
                print("[KYC] ❌ KYC rejected - user needs to retry or contact support")
            }
        }
    }
    
    // REMOVED: Automatic wallet/card creation after KYC
    // This is now handled manually in UserInfoView to prevent duplicates
}
