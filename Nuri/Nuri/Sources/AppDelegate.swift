import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let baseFont = UIFont(name: "Inter", size: 14) {
            let interFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFont)
            UILabel.appearance(whenContainedInInstancesOf: [UITabBar.self]).font = interFont
            let primary = UIColor(NuriAsset.primaryNuriBlack.swiftUIColor)
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
        }
        return true
    }
}
