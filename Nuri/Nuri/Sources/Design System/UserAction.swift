public struct UserAction: ViewModelViewState {
    public var action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public static func == (lhs: UserAction, rhs: UserAction) -> Bool {
        return true
    }

    public static var empty: UserAction { UserAction(action: {}) }
}
