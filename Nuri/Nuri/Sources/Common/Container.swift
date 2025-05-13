import Foundation

public enum ContainerMode {
    case retain
    case new
}

public protocol ContainerType {
    func register<T>(block: @escaping (ContainerType) -> T)
    func register<T>(mode: ContainerMode, block: @escaping (ContainerType) -> T)
    func resolve<T>() -> T
}

private struct ContainerEntry {
    var mode: ContainerMode
    var constructor: (ContainerType) -> Any
}

public final class Container: ContainerType {

    // MARK: - Variables

    private var registry: [String: ContainerEntry] = [:]
    private var retainer: [Any] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - ContainerType

    public func register<T>(block: @escaping (ContainerType) -> T) {
        register(mode: .retain, block: block)
    }

    public func register<T>(mode: ContainerMode, block: @escaping (ContainerType) -> T) {
        registry[String(describing: T.self)] = ContainerEntry(mode: mode, constructor: block)
    }

    
    public func resolve<T>() -> T {
        guard let entry = registry[String(describing: T.self)] else {
            fatalError("Type '\(T.self)' not registered.")
        }
        switch entry.mode {
        case .new:
            return entry.constructor(self) as! T
        case .retain:
            if let reference = retainer.first(where: { $0 is T }) {
                return reference as! T
            } else {
                let reference = entry.constructor(self) as! T
                retainer.append(reference)
                return reference
            }
        }
    }
}
