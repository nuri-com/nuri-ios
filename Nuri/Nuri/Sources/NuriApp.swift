import SwiftUI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    init() {
        // Don't initialize wallet on app start to avoid creating keychain entries
        print("🔑 [NuriApp] App started")
        // BitcoinWalletService will be initialized when Bitcoin tab is accessed
        
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
