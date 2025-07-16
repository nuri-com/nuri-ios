import Foundation

extension UInt64 {
    func toDate() -> Date {
        return Date(timeIntervalSince1970: TimeInterval(self))
    }
}