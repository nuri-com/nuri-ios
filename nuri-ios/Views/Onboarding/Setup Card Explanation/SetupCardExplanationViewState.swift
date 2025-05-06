struct SetupCardExplanationViewState: ViewModelViewState {
    let title: String
    let subtitle: String
    let illustrationName: String
    let continueButton: TextButtonViewState

    static var empty: SetupCardExplanationViewState {
        .init(title: "", subtitle: "", illustrationName: "", continueButton: .empty)
    }
}
