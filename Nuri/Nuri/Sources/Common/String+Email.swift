import Foundation

extension String {
    var isEmail: Bool {
        let emailRegEx = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegEx)
        return emailPredicate.evaluate(with: self)
    }
}
