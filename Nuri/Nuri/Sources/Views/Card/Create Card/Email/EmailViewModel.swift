import Combine

final class EmailViewModel: ObservableObject {

    // MARK: - Dependencies

    

    // MARK: - Variables

    @Published var viewState: EmailViewState = .empty
    var completion: (() -> Void)? = nil

    // MARK: - Initialization

    init() {
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
                isDisabled: true
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
        print("Continue")
    }
}
