struct EmailViewState: ViewModelViewState {
    let title: String
    let subtitle: String
    var emailTextField: TextFieldViewState
    var nextButton: TextButtonViewState
    var isLoading: Bool
    var showSMSView: Bool

    static var empty: EmailViewState {
        .init(
            title: "",
            subtitle: "",
            emailTextField: .empty,
            nextButton: .empty,
            isLoading: false,
            showSMSView: false
        )
    }

    enum Action: Equatable {
        case updateTextFieldValue(String)
        case showSMSView
        case showLoading
    }
}
