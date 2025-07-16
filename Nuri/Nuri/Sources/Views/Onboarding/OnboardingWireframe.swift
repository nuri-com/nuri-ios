import UIKit
import SwiftUI

protocol OnboardingWireframeType {
    func initialViewController() -> UIViewController
}

final class OnboardingWireframe: OnboardingWireframeType {

    private let container: ContainerType

    private var navigationController: UINavigationController?

    init(container: ContainerType) {
        self.container = container
    }

    func initialViewController() -> UIViewController {
        let viewController = viewController(for: .login)
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.tintColor = UIColor(NuriAsset.textPrimary.swiftUIColor)
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
        case .login:
            return .phoneNumber
        case .phoneNumber:
            return .verificationByCall
        case .verificationByCall:
            return .setupCardExplanation
        case .setupCardExplanation:
            return .setupCard
        case .setupCard:
            return .cardViewActive
        case .cardViewActive:
            return nil
        }
    }

    private func viewController(for screen: OnboardingScreen) -> UIViewController {
        switch screen {
        case .login:
            return loginViewController()
        case .phoneNumber:
            return phoneNumberViewController()
        case .verificationByCall:
            return verifyCallViewController()
        case .setupCardExplanation:
            return setupCardExplanationViewController()
        case .setupCard:
            return setupCardViewController()
        case .cardViewActive:
            return cardViewActiveController()
        }
    }

    private func passkeyLoginViewController() -> UIViewController {
        // PasskeyViewController removed - will be replaced with new integration
        return UIViewController()
    }

    private func loginViewController() -> UIViewController {
        let viewModel: LoginViewModelType = container.resolve()
        viewModel.delegate = self
        let view = LoginView(viewModel: viewModel.toViewModel())
        return hostingController(view: view)
    }

    private func phoneNumberViewController() -> UIViewController {
        return UIViewController()
    }

    private func verifyCallViewController() -> UIViewController {
        let viewModel: VerifyCallViewModelType = container.resolve()
        viewModel.delegate = self
        let view = VerifyCallView(viewModel: viewModel.toViewModel())
        return hostingController(view: view)
    }

    private func setupCardExplanationViewController() -> UIViewController {
        let viewModel: SetupCardExplanationViewModelType = container.resolve()
        viewModel.delegate = self
        let view = SetupCardExplanationView(viewModel: viewModel.toViewModel())
        return hostingController(view: view)
    }

    private func setupCardViewController() -> UIViewController {
//        let viewModel: SetupCardViewModelType = container.resolve()
//        viewModel.delegate = self
        let view = SetupCardView()
        return hostingController(view: view)
    }

    private func cardViewActiveController() -> UIViewController {
        let view = CardViewActive()
        return hostingController(view: view)
    }

    private func presentCountrySearch() {
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

extension OnboardingWireframe: LoginViewModelDelegate {

    func presentationAnchor() -> UIWindow {
        UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first!.windows.first!
    }
}
