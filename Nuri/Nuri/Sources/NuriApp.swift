import SwiftUI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    init() {
        // Ensure Privy SDK is up and set login flag accordingly
        _ = PrivyManager.shared
        if PrivyManager.currentUser != nil {
            isUserLoggedIn = true
        } else {
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
