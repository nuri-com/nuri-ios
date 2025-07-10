struct LoginViewState: ViewModelViewState {
    let title: String
    let subtitle: String
    let illustration: String
    var emailTextField: TextFieldViewState
    let orLabel: String
    let authButton: TextButtonViewState
    let appleLoginAction: UserAction


    static var empty: LoginViewState {
        .init(
            title: "",
            subtitle: "",
            illustration: "",
            emailTextField: .empty,
            orLabel: "",
            authButton: .empty,
            appleLoginAction: .empty
        )
    }
}
