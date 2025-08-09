struct EnterSMSCodeViewState: ViewModelViewState {
    var title: String
    let subtitle: String
    let illustrationName: String
    var codeTextField: TextFieldViewState
    var isLoadingAnimationActive: Bool
    var showKYC: Bool
    // Removed isCreatingCard - card creation happens automatically after KYC

    static var empty: EnterSMSCodeViewState {
        .init(
            title: "",
            subtitle: "",
            illustrationName: "",
            codeTextField: .empty,
            isLoadingAnimationActive: false,
            showKYC: false,
            // isCreatingCard removed
        )
    }

    enum Action: Equatable {
        case startLoadingAnimation
        // case showCreatingCardView removed - card creation is automatic
        case showKYC
    }
}
