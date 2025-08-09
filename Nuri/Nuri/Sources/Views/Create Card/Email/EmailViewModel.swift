import Combine
import Foundation

@MainActor
final class EmailViewModel: ObservableObject {

    // MARK: - Dependencies

    private let cardService = CardCreationServiceProvider.shared.service
    private let countryCode: String
    private let phoneNumber: String

    // MARK: - Variables

    @Published var viewState: EmailViewState = .empty

    // MARK: - Initialization

    init(countryCode: String, phoneNumber: String) {
        self.countryCode = countryCode
        self.phoneNumber = phoneNumber

        viewState = .init(
            title: "Your Email",
            subtitle: "Enter your email address to get started.",
            emailTextField: .init(
                label: "Email address",
                text: "",
                placeholder: "Email address"
            ),
            nextButton: .init(
                text: "Continue",
                action: { [weak self] in
                    self?.continueButtonPressed()
                },
                isDisabled: false
            ),
            isLoading: false,
            showSMSView: false
        )
    }

    // MARK: - Private

    private func updateViewState(action: EmailViewState.Action) {
        viewState = reduce(viewState, action: action)
    }

    private func reduce(_ viewState: EmailViewState, action: EmailViewState.Action) -> EmailViewState {
        var viewState = viewState
        switch action {
        case .updateTextFieldValue(let value):
            viewState.nextButton.isDisabled = value.isEmail
        case .showSMSView:
            viewState.showSMSView = true
        case .showLoading:
            viewState.isLoading = true
        }
        return viewState
    }

    private func continueButtonPressed() {
        print("[Lukas] continue button")
        
        // Save email and phone to StrigaSession for later user creation
        StrigaSession.shared.email = viewState.emailTextField.text
        StrigaSession.shared.phoneCountryCode = countryCode
        StrigaSession.shared.phoneNumber = phoneNumber
        
        print("[Lukas] Saved email and phone to session:")
        print("  - Email: \(viewState.emailTextField.text)")
        print("  - Phone Country Code: \(countryCode)")
        print("  - Phone Number: \(phoneNumber)")
        
        // DO NOT create user here! User will be created in EnterSMSCodeViewModel
        // after we have collected the name to prevent John Mock-Doe
        updateViewState(action: .showSMSView)
    }
}
