@testable import Nuri

final class TaskFactoryMock: TaskFactoryType {

    private(set) var capturedOperations: [@Sendable () async throws -> Void] = []

    // MARK: - TaskFactoryType

    var taskOperations: [@Sendable () async throws -> Void] = []
    var taskReturnValue: TaskType = TaskMock()
    func task(_ operation: @escaping @Sendable () async throws -> Void) -> TaskType {
        taskOperations.append(operation)
        return taskReturnValue
    }
}