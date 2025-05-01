import UIKit
import SwiftUI

protocol OnboardingWireframeType {
    func initialViewController() -> UIViewController
}

final class OnboardingWireframe: OnboardingWireframeType {

    private let container: ContainerType

    init(container: ContainerType) {
        self.container = container
    }

    func initialViewController() -> UIViewController {
        let viewController = viewController(for: .phoneNumber)
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        return navigationController
    }

    private func viewController(for screen: OnboardingScreen) -> UIViewController {
        switch screen {
        case .phoneNumber:
            return phoneNumberViewController()
        }
    }

    private func phoneNumberViewController() -> UIViewController {
        let viewModel: PhoneNumberViewModelType = container.resolve()
        let view = PhoneNumberView(viewModel: viewModel.toConcreteType())
        let viewController = UIHostingController(rootView: view)
        return viewController
    }
}
