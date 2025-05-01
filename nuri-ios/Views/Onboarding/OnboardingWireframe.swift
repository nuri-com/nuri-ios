import UIKit
import SwiftUI

protocol OnboardingWireframeType {
    func initialViewController() -> UIViewController
}

final class OnboardingWireframe: OnboardingWireframeType {

    private let container: ContainerType

    private var navigationController: UINavigationController?
    private var phoneNumberViewModel: PhoneNumberViewModelType?

    init(container: ContainerType) {
        self.container = container
    }

    func initialViewController() -> UIViewController {
        let viewController = viewController(for: .phoneNumber)
        let navigationController = UINavigationController(rootViewController: viewController)
        self.navigationController = navigationController
        return navigationController
    }

    private func showNextScreen(after screen: OnboardingScreen) {
        if let nextScreen = nextScreen(after: screen) {
            let viewController = viewController(for: nextScreen)
            navigationController?.pushViewController(viewController, animated: true)
        }
    }

    private func nextScreen(after screen: OnboardingScreen) -> OnboardingScreen? {
        switch screen {
        case .phoneNumber:
            return .verificationByCall
        case .verificationByCall:
            return nil
        }
    }

    private func viewController(for screen: OnboardingScreen) -> UIViewController {
        switch screen {
        case .phoneNumber:
            return phoneNumberViewController()
        case .verificationByCall:
            return verifyCallViewController()
        }
    }

    private func phoneNumberViewController() -> UIViewController {
        let viewModel: PhoneNumberViewModelType = container.resolve()
        viewModel.delegate = self
        phoneNumberViewModel = viewModel
        let view = PhoneNumberView(viewModel: viewModel.toViewModel())
        return hostingController(view: view)
    }

    private func verifyCallViewController() -> UIViewController {
        let viewModel: VerifyCallViewModelType = container.resolve()
        viewModel.delegate = self
        let view = VerifyCallView(viewModel: viewModel.toViewModel())
        return hostingController(view: view)
    }

    private func presentCountrySearch() {
        let viewModel: SearchCountryDialCodeViewModelType = container.resolve()
        viewModel.delegate = self
        let view = SearchCountryDialCodeView(viewModel: viewModel.toViewModel())
        let viewController = UIHostingController(rootView: view)
        navigationController?.present(viewController, animated: true)
    }

    private func hostingController<V: View>(view: V) -> UIViewController {
        let viewController = UIHostingController(rootView: view)
        viewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        return viewController
    }
}

extension OnboardingWireframe: OnboardingScreenDelegate {

    func didFinish(screen: OnboardingScreen) {
        showNextScreen(after: screen)
    }
}

extension OnboardingWireframe: PhoneNumberViewModelDelegate {

    func phoneNumberViewModelDidSelectSearch() {
        presentCountrySearch()
    }
}

extension OnboardingWireframe: SearchCountryDialCodeViewModelDelegate {

    func searchCancelled() {
        navigationController?.presentedViewController?.dismiss(animated: true)
    }

    func didSelectCountry(countryCode: String) {
        navigationController?.presentedViewController?.dismiss(animated: true)
        phoneNumberViewModel?.updateSelectedCountry(countryCode: countryCode)
    }
}
