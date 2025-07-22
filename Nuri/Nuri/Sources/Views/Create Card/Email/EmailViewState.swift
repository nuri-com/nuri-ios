struct EmailViewState: ViewModelViewState {
    let title: String
    let subtitle: String
    var emailTextField: TextFieldViewState
    var nextButton: TextButtonViewState

    static var empty: EmailViewState {
        .init(
            title: "",
            subtitle: "",
            emailTextField: .empty,
            nextButton: .empty
        )
    }

    enum Action: Equatable {
        case updateTextFieldValue(String)
    }
}
