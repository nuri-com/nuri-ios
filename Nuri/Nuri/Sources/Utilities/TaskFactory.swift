import Foundation

protocol TaskFactoryType {
    @discardableResult
    func task(_ operation: @escaping @Sendable () async throws -> Void) -> TaskType
}

final class TaskFactory: TaskFactoryType {

    @discardableResult
    func task(_ operation: @escaping @Sendable () async throws -> Void) -> TaskType {
        return Task(operation: operation)
    }
}
