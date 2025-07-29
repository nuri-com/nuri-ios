import Foundation

public protocol ObserverType: NSObjectProtocol {
    var key: String { get }
    var nsObject: NSObject { get }
}

public class Observer: NSObject, ObserverType {

    // MARK: - Variables

    private let callback: () -> Void

    // MARK: - Initialization

    public init(key: String, callback: @escaping () -> Void) {
        self.key = key
        self.callback = callback
        super.init()
    }

    // MARK: - ObserverType

    public let key: String

    public var nsObject: NSObject {
        return self
    }

    // MARK: - KVO

    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == key else { return }
        callback()
    }
}
