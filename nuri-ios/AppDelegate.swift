import UIKit

@main
final class AppDelegate: NSObject, UIApplicationDelegate {

    var window: UIWindow?

    private let container: ContainerType = Container()
    private lazy var rootWireframe: RootWireframeType = {
        container.resolve()
    }()

    func applicationDidFinishLaunching(_ application: UIApplication) {
        injectDependencies(into: container)
        setupUI()
    }

    private func setupUI() {
        let viewController = rootWireframe.start()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = viewController
        self.window = window
        window.makeKeyAndVisible()
    }
}

