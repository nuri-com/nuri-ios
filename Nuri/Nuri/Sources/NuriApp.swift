import SwiftUI
import StrigaAPI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    init() {
        // Don't initialize wallet on app start to avoid creating keychain entries
        print("🔑 [NuriApp] App started")
        // BitcoinWalletService will be initialized when Bitcoin tab is accessed
        
        // Simple check - don't trust stored tokens, always start with welcome screen
        // Let Privy and the welcome screen handle authentication state properly
        print("🔑 [NuriApp] App started - user will authenticate via welcome screen")
        isUserLoggedIn = true
        StrigaService.shared.configuration = .init(
            url: "https://www.sandbox.striga.com/api/",
            key: "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=",
            secret: "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE="
        )
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
