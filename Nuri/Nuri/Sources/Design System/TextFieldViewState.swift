public struct TextFieldViewState: ViewModelViewState {
    public let label: String
    public var text: String
    public let placeholder: String
    public let textChangeHandler: UserObjectAction<String>?
    public let submitHandler: UserAction?

    public init(label: String, text: String, placeholder: String, textChangeHandler: UserObjectAction<String>? = nil, submitHandler: UserAction? = nil) {
        self.label = label
        self.text = text
        self.placeholder = placeholder
        self.textChangeHandler = textChangeHandler
        self.submitHandler = submitHandler
    }

    public static var empty: TextFieldViewState {
        .init(label: "", text: "", placeholder: "")
    }
}
