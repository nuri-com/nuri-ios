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
        
        // Uncomment to force logout for testing
        // UserDefaults.standard.set(false, forKey: "isUserLoggedIn")
        // print("🔓 [NuriApp] Login state reset to: \(UserDefaults.standard.bool(forKey: "isUserLoggedIn"))")
        
        // Don't clear cache on app start - let the wallet service handle it
        // This prevents losing cached balance data
        print("💾 [NuriApp] Preserving cached wallet data on app start")
        
        // Log device info for debugging
        #if targetEnvironment(simulator)
        print("🖥️ [NuriApp] Running on Simulator")
        #else
        print("📱 [NuriApp] Running on Physical Device")
        #endif
        
        // Configure Striga service
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
                            print("📊 [NuriApp] Current login state: \(isUserLoggedIn)")
                        }
                } else {
                    WelcomeView()
                        .onAppear {
                            print("👋 [NuriApp] Showing WelcomeView (user not logged in)")
                            print("📊 [NuriApp] Current login state: \(isUserLoggedIn)")
                            print("🔐 [NuriApp] Ready for passkey authentication")
                        }
                }
            }
            .onAppear {
                print("🔍 [NuriApp] View appeared - isUserLoggedIn = \(isUserLoggedIn)")
                print("📝 [NuriApp] UserDefaults value = \(UserDefaults.standard.bool(forKey: "isUserLoggedIn"))")
            }
        }
    }
}
