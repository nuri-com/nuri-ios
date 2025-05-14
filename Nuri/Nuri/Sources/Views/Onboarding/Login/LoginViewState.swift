struct LoginViewState: ViewModelViewState {
    let title: String
    let subtitle: String
    let illustration: String
    var emailTextField: TextFieldViewState
    let orLabel: String
    let passkeyButton: TextButtonViewState


    static var empty: LoginViewState {
        .init(
            title: "",
            subtitle: "",
            illustration: "",
            emailTextField: .empty,
            orLabel: "",
            passkeyButton: .empty,
        )
    }
}
