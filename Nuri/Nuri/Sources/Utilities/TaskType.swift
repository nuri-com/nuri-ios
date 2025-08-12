protocol TaskType {
    func cancel()
}

extension Task: TaskType {}
