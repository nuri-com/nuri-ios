public struct UserObjectAction<O>: ViewModelViewState {
    public var action: (O) -> Void

    public init(action: @escaping (O) -> Void) {
        self.action = action
    }

    public static func == (lhs: UserObjectAction, rhs: UserObjectAction) -> Bool {
        return true
    }
    
    public static var empty: UserObjectAction<O> {
        .init(action: { _ in })
    }
}
