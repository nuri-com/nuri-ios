import SwiftUI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

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
