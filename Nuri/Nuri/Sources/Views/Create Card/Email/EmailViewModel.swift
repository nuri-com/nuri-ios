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
        Task {
            do {
                let timestamp = Int(Date().timeIntervalSince1970)
                let firstName = "first\(timestamp)"
                let lastName = "last\(timestamp)"
                let name = "\(firstName) \(lastName)"
                let address = CreateUser.Address(
                    addressLine1: "Sonnenallee 1",
                    city: "Berlin",
                    country: "DE",
                    postalCode: "12047"
                )
                let input = CreateUser(
                    firstName: firstName,
                    lastName: lastName,
                    email: viewState.emailTextField.text,
                    mobile: .init(
                        countryCode: countryCode,
                        number: phoneNumber
                    ),
                    address: address,
                    dateOfBirth: .init(year: 2005, month: 1, day: 1)
                )
                updateViewState(action: .showLoading)
                let userResponse = try await strigaService.createUser(input)
                StrigaSession.shared.userId = userResponse.userId
                StrigaSession.shared.name = name
                StrigaSession.shared.address = address
                print("[Lukas] success \(userResponse)")
                updateViewState(action: .showSMSView)
            } catch {
                print("[Lukas] error \(error)")
            }
        }
    }
}
