import SwiftUI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    init() {
        // Initialize Privy SDK
        _ = PrivyManager.shared
        
        // Simple check - don't trust stored tokens, always start with welcome screen
        // Let Privy and the welcome screen handle authentication state properly
        print("🔑 [NuriApp] App started - user will authenticate via welcome screen")
        isUserLoggedIn = true
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
