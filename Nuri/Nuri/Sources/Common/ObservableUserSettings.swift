import Combine
import Foundation

final class ObservableUserSettings {

    // MARK: - Dependencies

    private let userDefaults = UserDefaults.standard
    private let userSettings = UserSettings()
    private let observerFactory = ObserverFactory()

    // MARK: - Variables

    private var observers: [ObserverType] = []

    // MARK: - HomeStorageType

    lazy var strigaUserId: AnyPublisher<String?, Never> = {
        observedStream(key: .strigaUserId) { [weak self] in
            return self?.userSettings.strigaUserId
        }
    }()
    
    lazy var strigaCardId: AnyPublisher<String?, Never> = {
        observedStream(key: .strigaCardId) { [weak self] in
            return self?.userSettings.strigaCardId
        }
    }()
    
    lazy var strigaWalletId: AnyPublisher<String?, Never> = {
        observedStream(key: .strigaWalletId) { [weak self] in
            return self?.userSettings.strigaWalletId
        }
    }()

    // MARK: - Private

    private func observedStream<T>(key: UserSettingsKey, fetch: @escaping () -> T?) -> AnyPublisher<T?, Never> {
        let stream = CurrentValueSubject<T?, Never>(fetch())
        addObserver(key: key) {
            stream.send(fetch())
        }
        return stream.eraseToAnyPublisher()
    }

    private func addObserver(key: UserSettingsKey, callback: @escaping () -> Void) {
        let observer = observerFactory.create(key: key.rawValue, callback: callback)
        userDefaults.addObserver(observer.nsObject, forKeyPath: observer.key, options: .new, context: nil)
        observers.append(observer)
    }
}
