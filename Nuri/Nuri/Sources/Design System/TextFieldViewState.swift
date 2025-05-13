public struct TextFieldViewState: ViewModelViewState {
    public let label: String
    public var text: String
    public let placeholder: String
    public let textChangeHandler: UserObjectAction<String>?

    public init(label: String, text: String, placeholder: String, textChangeHandler: UserObjectAction<String>? = nil) {
        self.label = label
        self.text = text
        self.placeholder = placeholder
        self.textChangeHandler = textChangeHandler
    }

    public static var empty: TextFieldViewState {
        .init(label: "", text: "", placeholder: "")
    }
}
