import Foundation

enum UserSettingsKey: String {
    case strigaUserId
    case strigaCardId
    case strigaWalletId
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
    
    var strigaCardId: String? {
        get { value(forKey: .strigaCardId) as? String }
        set { setValue(newValue, forKey: .strigaCardId) }
    }
    
    var strigaWalletId: String? {
        get { value(forKey: .strigaWalletId) as? String }
        set { setValue(newValue, forKey: .strigaWalletId) }
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
