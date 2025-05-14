import UIKit

fileprivate let container: ContainerType = Container()

@main
final class AppDelegate: NSObject, UIApplicationDelegate {

    func applicationDidFinishLaunching(_ application: UIApplication) {
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
