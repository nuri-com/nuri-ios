import SwiftUI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    init() {
        // Initialize Privy SDK
        _ = PrivyManager.shared
        
        // Check if we have stored tokens to determine login state
        let tokens = PasskeyService.getStoredTokens()
        if tokens.0 != nil && tokens.2 != nil {
            print("🔑 [NuriApp] Found stored tokens, user should be logged in")
            // Initialize wallet service for this user
            if let userID = tokens.2 {
                print("🔑 [NuriApp] Pre-initializing wallet for user: \(userID)")
                BitcoinWalletService.shared.initializeForUser(userID)
            }
            isUserLoggedIn = true
        } else {
            print("❌ [NuriApp] No stored tokens found, user logged out")
            isUserLoggedIn = false
        }
    }

    var body: some Scene {
        WindowGroup {
            if isUserLoggedIn {
                MainTabBar()
            } else {
                WelcomeView()
            }
        }
    }
}
