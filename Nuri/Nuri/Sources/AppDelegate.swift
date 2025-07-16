import UIKit
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 [AppDelegate] App launched")
        
        // Don't authenticate on app launch - wait for wallet access
        // authenticateUser()
        
        // Continue with existing UI customization
        if let baseFont = UIFont(name: "Inter", size: 14) {
            let interFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFont)
            UILabel.appearance(whenContainedInInstancesOf: [UITabBar.self]).font = interFont
            let primary = UIColor(red: 0x2C/255.0, green: 0x23/255.0, blue: 0x2E/255.0, alpha: 1.0) // #2C232E
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: interFont,
                .foregroundColor: primary.withAlphaComponent(0.5)
            ]
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .font: interFont,
                .foregroundColor: primary
            ]
            UITabBarItem.appearance().setTitleTextAttributes(normalAttributes, for: .normal)
            UITabBarItem.appearance().setTitleTextAttributes(selectedAttributes, for: .selected)
            UITabBarItem.appearance().titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 5)

            // Customise TabBar background to match app background and remove top divider
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(NuriAsset.background.swiftUIColor)
            tabBarAppearance.shadowColor = .clear // remove divider

            // Apply the same text attributes to the stacked layout appearance so they are
            // respected when the system renders items.
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes

            UITabBar.appearance().standardAppearance = tabBarAppearance
            // Since iOS 15 `scrollEdgeAppearance` controls the translucent state when scrolled to edge
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 [AppDelegate] App will enter foreground")
        // Reset authentication state in AuthenticationService
        AuthenticationService.shared.resetAuthentication()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 [AppDelegate] App entered background")
        // Reset authentication state
        AuthenticationService.shared.resetAuthentication()
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Currently no special URL handling needed
        return false
    }
}
