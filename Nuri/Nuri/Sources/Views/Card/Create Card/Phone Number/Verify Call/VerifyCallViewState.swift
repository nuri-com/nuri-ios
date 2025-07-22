struct VerifyCallViewState: ViewModelViewState {
    var title: String
    let subtitle: String
    let illustrationName: String
    var successMessage: String?

    static var empty: VerifyCallViewState {
        .init(title: "", subtitle: "", illustrationName: "", successMessage: nil)
    }
}
