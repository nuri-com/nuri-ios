import Foundation

enum UserSettingsKey: String {
    case strigaUserId
}

final class UserSettings {

    // MARK: - Dependencies

    private let userDefaults = UserDefaults.standard
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    // MARK: - UserSettingsType

    var strigaUserId: String? {
        get { value(forKey: .strigaUserId) as? String }
        set { setValue(newValue, forKey: .strigaUserId) }
    }

    func addObserver(_ observer: ObserverType) {
        userDefaults.addObserver(observer.nsObject, forKeyPath: observer.key, options: .new, context: nil)
    }

    // MARK: - Private

    private func bool(forKey key: UserSettingsKey) -> Bool {
        return userDefaults.bool(forKey: key.rawValue)
    }

    private func value(forKey key: UserSettingsKey) -> Any? {
        return userDefaults.value(forKey: key.rawValue)
    }

    private func setValue(_ value: Any?, forKey key: UserSettingsKey) {
        return userDefaults.setValue(value, forKey: key.rawValue)
    }

    private func object<T: Decodable>(forKey key: UserSettingsKey) -> T? {
        guard let data = userDefaults.value(forKey: key.rawValue) as? Data else { return nil }
        return try? jsonDecoder.decode(T.self, from: data)
    }

    private func setObject<T: Encodable>(_ value: T, forKey key: UserSettingsKey) {
        guard let data = try? jsonEncoder.encode(value) else { return }
        userDefaults.setValue(data, forKey: key.rawValue)
    }
}
