import UIKit
import SwiftUI

protocol OnboardingWireframeType {
    func viewController() -> UIViewController
}

final class OnboardingWireframe: OnboardingWireframeType {

    private let container: ContainerType

    init(container: ContainerType) {
        self.container = container
    }

    func viewController() -> UIViewController {
        let viewController = initialViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        return navigationController
    }

    private func initialViewController() -> UIViewController {
        let viewModel: PhoneNumberViewModelType = container.resolve()
        let view = PhoneNumberView(viewModel: viewModel.toConcreteType())
        let viewController = UIHostingController(rootView: view)
        return viewController
    }
}
