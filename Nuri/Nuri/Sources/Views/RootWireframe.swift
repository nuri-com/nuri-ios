import UIKit

protocol RootWireframeType {
    func start() -> UIViewController
}

final class RootWireframe: RootWireframeType {

    private let onboardingWireframe: OnboardingWireframeType

    init(onboardingWireframe: OnboardingWireframeType) {
        self.onboardingWireframe = onboardingWireframe
    }

    func start() -> UIViewController {
        return onboardingWireframe.initialViewController()
    }
}
