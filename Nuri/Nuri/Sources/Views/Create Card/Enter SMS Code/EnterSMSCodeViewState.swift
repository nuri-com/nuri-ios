struct EnterSMSCodeViewState: ViewModelViewState {
    var title: String
    let subtitle: String
    let illustrationName: String
    var codeTextField: TextFieldViewState
    var isLoadingAnimationActive: Bool
    var showKYC: Bool
    var isCreatingCard: Bool

    static var empty: EnterSMSCodeViewState {
        .init(
            title: "",
            subtitle: "",
            illustrationName: "",
            codeTextField: .empty,
            isLoadingAnimationActive: false,
            showKYC: false,
            isCreatingCard: false
        )
    }

    enum Action: Equatable {
        case startLoadingAnimation
        case showCreatingCardView
        case showKYC
    }
}
