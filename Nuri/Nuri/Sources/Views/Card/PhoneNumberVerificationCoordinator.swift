
import SwiftUI
import UIKit

struct PhoneNumberVerificationCoordinator: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let container = Container()
        injectDependencies(into: container)
        let wireframe = OnboardingWireframe(container: container)
        let navigationController = wireframe.phoneNumberVerificationFlow()
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No update needed
    }
}
