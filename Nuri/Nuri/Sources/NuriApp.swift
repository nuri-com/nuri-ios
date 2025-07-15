import SwiftUI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    init() {
        // Don't initialize wallet on app start to avoid creating keychain entries
        print("🔑 [NuriApp] App started")
        // BitcoinWalletService will be initialized when Bitcoin tab is accessed
        
        // Force logout for testing - uncomment this line to reset login state
        // UserDefaults.standard.set(false, forKey: "isUserLoggedIn")
        // print("🔓 [NuriApp] Login state reset to: \(UserDefaults.standard.bool(forKey: "isUserLoggedIn"))")
        
        // Don't clear cache on app start - let the wallet service handle it
        // This prevents losing cached balance data
        print("💾 [NuriApp] Preserving cached wallet data on app start")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isUserLoggedIn {
                    MainTabBar()
                        .onAppear {
                            print("📱 [NuriApp] Showing MainTabBar (user logged in)")
                        }
                } else {
                    WelcomeView()
                        .onAppear {
                            print("👋 [NuriApp] Showing WelcomeView (user not logged in)")
                        }
                }
            }
            .onAppear {
                print("🔍 [NuriApp] isUserLoggedIn = \(isUserLoggedIn)")
            }
        }
    }
}
