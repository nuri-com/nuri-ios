struct EnterSMSCodeViewState: ViewModelViewState {
    var title: String
    let subtitle: String
    let illustrationName: String
    var codeTextField: TextFieldViewState

    static var empty: EnterSMSCodeViewState {
        .init(
            title: "",
            subtitle: "",
            illustrationName: "",
            codeTextField: .empty
        )
    }
}
