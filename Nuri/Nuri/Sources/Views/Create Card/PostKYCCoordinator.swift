import SwiftUI
import UIKit

// MARK: - Post-KYC Flow Coordinator
// This coordinator manages the flow after successful KYC approval
// Flow: KYC Approved → UserInfoView → Manual Wallet/Card Creation → Main App

class PostKYCCoordinator: ObservableObject {
    static let shared = PostKYCCoordinator()
    
    private init() {}
    
    // MARK: - Present User Info After KYC
    // This should be called after KYC is approved
    // It presents UserInfoView in a new modal context, completely separate from SMS flow
    func presentUserInfoAfterKYC() {
        DispatchQueue.main.async {
            print("\n" + String(repeating: "=", count: 80))
            print("🎯 [PostKYCCoordinator] STARTING POST-KYC FLOW")
            print("   ✅ KYC Approved")
            print("   📋 Presenting User Info View")
            print("   ⚠️ SMS screen will NOT be shown again")
            print(String(repeating: "=", count: 80))
            
            // Get the current window
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                print("[PostKYCCoordinator] ❌ Could not find window")
                return
            }
            
            // Create the UserInfoView wrapped in a hosting controller
            let userInfoView = UserInfoView()
            let hostingController = UIHostingController(rootView: userInfoView)
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.modalTransitionStyle = .coverVertical
            
            // Dismiss any existing modal (including SMS screen) and present UserInfoView
            if let rootVC = window.rootViewController {
                // First dismiss any existing modals (this closes SMS screen)
                rootVC.dismiss(animated: false) {
                    print("[PostKYCCoordinator] ✅ Dismissed SMS/KYC flow")
                    
                    // Then present UserInfoView in a new modal context
                    rootVC.present(hostingController, animated: true) {
                        print("[PostKYCCoordinator] ✅ Presented UserInfoView")
                        print("[PostKYCCoordinator] 📝 User can now manually create wallet/card")
                    }
                }
            }
        }
    }
    
    // MARK: - Dismiss to Main App
    // Called when user completes or skips wallet creation
    func dismissToMainApp() {
        DispatchQueue.main.async {
            print("\n" + String(repeating: "=", count: 80))
            print("🎯 [PostKYCCoordinator] COMPLETING POST-KYC FLOW")
            print("   ✅ Returning to main app")
            print("   ⚠️ SMS screen will NOT be shown")
            print(String(repeating: "=", count: 80))
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController else {
                print("[PostKYCCoordinator] ❌ Could not find window")
                return
            }
            
            // Dismiss ALL modals to return to main app
            rootVC.dismiss(animated: true) {
                print("[PostKYCCoordinator] ✅ Returned to main app")
                
                // Post notification that onboarding is complete
                NotificationCenter.default.post(
                    name: Notification.Name("OnboardingCompleted"),
                    object: nil,
                    userInfo: ["hasCard": UserSettings().strigaCardId != nil]
                )
            }
        }
    }
}

// MARK: - Flow Steps Summary
/*
 ONBOARDING FLOW - CLEAR SEPARATION OF STEPS:
 
 ═══════════════════════════════════════════════════════════════
 STEP 1: USER REGISTRATION
 ═══════════════════════════════════════════════════════════════
 1. Phone Number Entry
 2. Create Striga User (NOT wallet)
 3. SMS Sent by Striga
 
 ═══════════════════════════════════════════════════════════════
 STEP 2: SMS VERIFICATION
 ═══════════════════════════════════════════════════════════════
 1. User enters SMS code
 2. Code verified with Striga
 3. Start KYC process
 ⚠️ AFTER THIS POINT: SMS SCREEN NEVER SHOWN AGAIN
 
 ═══════════════════════════════════════════════════════════════
 STEP 3: KYC PROCESS
 ═══════════════════════════════════════════════════════════════
 1. Sumsub SDK handles KYC
 2. On approval → PostKYCCoordinator.presentUserInfoAfterKYC()
 3. SMS flow is completely dismissed
 
 ═══════════════════════════════════════════════════════════════
 STEP 4: POST-KYC USER INFO (NEW MODAL)
 ═══════════════════════════════════════════════════════════════
 1. Show user details (name, email, phone)
 2. Manual "Create Wallet & Card" button
 3. CardCreationService ensures ONE wallet, ONE card, ONE IBAN
 
 ═══════════════════════════════════════════════════════════════
 STEP 5: RETURN TO MAIN APP
 ═══════════════════════════════════════════════════════════════
 1. User clicks "Continue to App" or "Skip for Now"
 2. PostKYCCoordinator.dismissToMainApp()
 3. All modals dismissed, back to main app
 
 IMPORTANT RULES:
 ✅ SMS screen is ONLY for verification, never shown after KYC
 ✅ NO automatic wallet/card creation
 ✅ User has full control over wallet/card creation
 ✅ ONE wallet, ONE card, ONE IBAN per user (enforced by CardCreationService)
 */