extension String {
    var withZeroWidthSpaces: String {
        map({ String($0) }).joined(separator: "\u{200B}")
    }
}
