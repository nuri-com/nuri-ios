import SwiftUI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    init() {
        // Initialize Bitcoin wallet automatically when app starts
        print("🔑 [NuriApp] App started - initializing Bitcoin wallet")
        BitcoinWalletService.shared.initializeWalletOnAppStart()
        
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
