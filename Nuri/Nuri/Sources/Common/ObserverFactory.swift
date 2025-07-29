final class ObserverFactory {
    func create(key: String, callback: @escaping () -> Void) -> ObserverType {
        Observer(key: key, callback: callback)
    }
}
