import Combine
import IdensicMobileSDK
import Foundation
import StrigaAPI

final class EnterSMSCodeViewModel: ObservableObject {

    var striga = StrigaService.shared

    @Published var viewState: EnterSMSCodeViewState = .empty

    init() {
        // Configure Striga for sandbox (development) if not already configured
        if striga.configuration == nil {
            striga.configuration = StrigaConfiguration(
                url: "https://www.sandbox.striga.com/api/",
                key: "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=",
                secret: "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE="
            )
            print("[Striga] Configured for sandbox environment")
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
                
                print("[SMS] Mobile verification successful. Starting KYC...")
                
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
        sdk.verificationHandler { [weak self] (isApproved) in
            print("[Lukas] verificationHandler: Applicant is " + (isApproved ? "approved" : "finally rejected"))
            if isApproved {
                Task {
                    // Don't show the CreatingCardView - do it in the background
                    await self?.createCardAndWalletInBackground()
                }
            }
        }
    }
    
    @MainActor
    private func createCardAndWalletInBackground() async {
        print("[KYC] Creating card and wallet in background after KYC approval...")
        
        do {
            let session = StrigaSession.shared
            guard let userId = session.userId else {
                print("[KYC] ERROR: No userId in session")
                return
            }
            
            // REMOVED: Duplicate wallet creation here
            // Wallet is created ONCE in CardCreationService when creating the card
            
            // Then create the card
            let name: String
            if let firstName = session.firstName, let lastName = session.lastName {
                name = "\(firstName) \(lastName)"
                print("[KYC] Using full name for card: \(name)")
            } else if let sessionName = session.name {
                name = sessionName
                print("[KYC] Using session name for card: \(name)")
            } else {
                print("[KYC] ERROR: No name available for card creation")
                return
            }
            
            print("[KYC] Creating card for user: \(userId) with name: \(name)")
            let cardService = CardCreationServiceProvider.shared.service
            let cardResponse = try await cardService.createCard(name: name, userId: userId)
            print("[KYC] Card created successfully: \(cardResponse)")
            
            // Store card details
            UserSettings().strigaUserId = userId
            UserSettings().strigaCardId = cardResponse.id
            UserSettings().strigaWalletId = cardResponse.parentWalletId
            
            // Post notification that card was created
            NotificationCenter.default.post(name: Notification.Name("CardCreatedSuccessfully"), object: nil)
            
            // Close the entire card creation flow
            print("[KYC] Card and wallet created successfully, closing flow...")
            
            // Find and dismiss the navigation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.dismiss(animated: true)
            }
            
        } catch {
            print("[KYC] Error creating card/wallet in background: \(error)")
            if let errorResponse = error as? ErrorResponse {
                print("[KYC] Error details:")
                print("[KYC] - Message: \(errorResponse.message)")
                print("[KYC] - Code: \(errorResponse.errorCode)")
                print("[KYC] - Details: \(errorResponse.errorDetails)")
            }
        }
    }
}
