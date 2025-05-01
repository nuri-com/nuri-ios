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
        let nextScreen = nextScreen(after: screen)
        let viewController = viewController(for: nextScreen)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func nextScreen(after screen: OnboardingScreen) -> OnboardingScreen {
        switch screen {
        case .phoneNumber:
            return .verificationByCall
        case .verificationByCall:
            fatalError()
        }
    }

    private func viewController(for screen: OnboardingScreen) -> UIViewController {
        switch screen {
        case .phoneNumber:
            return phoneNumberViewController()
        case .verificationByCall:
            return verificationByCallViewController()
        }
    }

    private func phoneNumberViewController() -> UIViewController {
        let viewModel: PhoneNumberViewModelType = container.resolve()
        viewModel.delegate = self
        phoneNumberViewModel = viewModel
        let view = PhoneNumberView(viewModel: viewModel.toViewModel())
        return UIHostingController(rootView: view)
    }

    private func verificationByCallViewController() -> UIViewController {
//        let viewModel: PhoneNumberViewModelType = container.resolve()
//        let view = PhoneNumberView(viewModel: viewModel.toViewModel())
//        let viewController = UIHostingController(rootView: view)
//        return viewController

        fatalError()
    }

    private func presentCountrySearch() {
        let viewModel: SearchCountryDialCodeViewModelType = container.resolve()
        viewModel.delegate = self
        let view = SearchCountryDialCodeView(viewModel: viewModel.toViewModel())
        let viewController = UIHostingController(rootView: view)
        navigationController?.present(viewController, animated: true)
    }
}

extension OnboardingWireframe: OnboardingScreenDelegate {

    func didFinish(screen: OnboardingScreen) {
        showNextScreen(after: .phoneNumber)
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
