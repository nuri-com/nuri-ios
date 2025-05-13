import SwiftUI

public struct TextButtonViewState: ViewModelViewState {
    public var text: String
    public var action: UserAction
    public var isDisabled: Bool

    public init(text: String, action: @escaping () -> Void, isDisabled: Bool = false) {
        self.text = text
        self.action = UserAction(action: action)
        self.isDisabled = isDisabled
    }

    public init(text: String, action: UserAction, isDisabled: Bool = false) {
        self.text = text
        self.action = action
        self.isDisabled = isDisabled
    }

    public static var empty: TextButtonViewState {
        .init(text: "", action: .empty)
    }
}

public struct TextButton: View {

    // MARK: - Variables

    private let viewState: TextButtonViewState

    // MARK: - Initialization

    public init(viewState: TextButtonViewState) {
        self.viewState = viewState
    }

    // MARK: - View

    public var body: some View {
        Button(action: viewState.action.action) {
            Text(viewState.text)
        }
        .disabled(viewState.isDisabled)
    }
}
