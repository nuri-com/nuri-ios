import UIKit

fileprivate let container: ContainerType = Container()

final class AppDelegate: NSObject, UIApplicationDelegate {

    func applicationDidFinishLaunching(_ application: UIApplication) {
        // Use Dynamic-Type: Inter scaled for .caption1 so it responds to system text-size changes
        if let baseFont = UIFont(name: "Inter", size: 14) {
            let interFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFont)

            // Force UILabels inside UITabBar to use Inter 14
            UILabel.appearance(whenContainedInInstancesOf: [UITabBar.self]).font = interFont

            // Colors
            let primary = UIColor(named: "PrimaryNuriBlack") ?? .black

            // 50%‐opacity black when inactive, 100% black when selected
            let normalAttributes: [NSAttributedString.Key: Any] = [.font: interFont,
                                                                    .foregroundColor: primary.withAlphaComponent(0.5)]
            let selectedAttributes: [NSAttributedString.Key: Any] = [.font: interFont,
                                                                      .foregroundColor: primary]

            UITabBarItem.appearance().setTitleTextAttributes(normalAttributes, for: .normal)
            UITabBarItem.appearance().setTitleTextAttributes(selectedAttributes, for: .selected)

            // iOS 13+: configure UITabBarAppearance so system actually uses custom font & colours
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            appearance.stackedLayoutAppearance.normal.iconColor = primary.withAlphaComponent(0.5)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            appearance.stackedLayoutAppearance.selected.iconColor = primary

            appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
            appearance.inlineLayoutAppearance.normal.iconColor = primary.withAlphaComponent(0.5)
            appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            appearance.inlineLayoutAppearance.selected.iconColor = primary

            appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
            appearance.compactInlineLayoutAppearance.normal.iconColor = primary.withAlphaComponent(0.5)
            appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            appearance.compactInlineLayoutAppearance.selected.iconColor = primary

            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }

            // Ensure selected item uses black (primary) and unselected 50% opacity
            UITabBar.appearance().tintColor = primary
            UITabBar.appearance().unselectedItemTintColor = primary.withAlphaComponent(0.5)
        }

        injectDependencies(into: container)
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

final class SceneDelegate: NSObject, UISceneDelegate {

    var window: UIWindow?

    private lazy var rootWireframe: RootWireframeType = {
        container.resolve()
    }()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = rootWireframe.start()
        self.window = window
        window.makeKeyAndVisible()
    }
}
