import Combine
import StrigaAPI
import Foundation

@MainActor
final class EmailViewModel: ObservableObject {

    // MARK: - Dependencies

    private let strigaService = StrigaService.shared
    private let countryCode: String
    private let phoneNumber: String

    // MARK: - Variables

    @Published var viewState: EmailViewState = .empty

    // MARK: - Initialization

    init(countryCode: String, phoneNumber: String) {
        self.countryCode = countryCode
        self.phoneNumber = phoneNumber

        let timestamp = Int(Date().timeIntervalSince1970)
        viewState = .init(
            title: "Your Email",
            subtitle: "Enter your email address to get started.",
            emailTextField: .init(
                label: "Email address",
                text: "email+\(timestamp)@nuri.com",
                placeholder: "Email address"
            ),
            nextButton: .init(
                text: "Continue",
                action: { [weak self] in
                    self?.continueButtonPressed()
                },
                isDisabled: false
            )
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
        }
        return viewState
    }

    private func continueButtonPressed() {
        print("[Lukas] continue button")
        Task {
            do {
                let timestamp = Int(Date().timeIntervalSince1970)
                let input = CreateUser(
                    firstName: "first\(timestamp)",
                    lastName: "last\(timestamp)",
                    email: viewState.emailTextField.text,
                    mobile: .init(
                        countryCode: countryCode,
                        number: phoneNumber
                    ),
                    address: nil
                )
                let userResponse = try await strigaService.createUser(input)
                print("[Lukas] success \(userResponse)")
            } catch {
                print("[Lukas] error \(error)")
            }
        }
    }
}
