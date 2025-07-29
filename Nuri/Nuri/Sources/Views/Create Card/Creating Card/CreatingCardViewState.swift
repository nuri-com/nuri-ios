struct CreatingCardViewState: ViewModelViewState {
    var title: String
    let subtitle: String
    let illustrationName: String
    var isLoading: Bool
    var isFinished: Bool

    static var empty: Self {
        .init(
            title: "",
            subtitle: "",
            illustrationName: "",
            isLoading: false,
            isFinished: false
        )
    }

    enum Action: Equatable {
        case finish
    }
}
