public struct PickerViewState: ViewModelViewState {
    public let label: String
    public let options: [String]
    public var selection: Int
    public var isDisabled: Bool
    public let disabledText: String?
    public let selectionChangeHandler: UserObjectAction<Int>?

    public init(label: String, options: [String], selection: Int, isDisabled: Bool = false, disabledText: String? = nil, selectionChangeHandler: UserObjectAction<Int>? = nil) {
        self.label = label
        self.options = options
        self.selection = selection
        self.isDisabled = isDisabled
        self.disabledText = disabledText
        self.selectionChangeHandler = selectionChangeHandler
    }

    public static var empty: PickerViewState {
        .init(label: "", options: [], selection: 0)
    }
}
