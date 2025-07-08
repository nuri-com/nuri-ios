import Foundation
import CryptoKit
import KeychainAccess

/// Utility to backup and restore sensitive wallet data to the user's iCloud container.
/// The backup is encrypted locally using AES.GCM before being written to iCloud.
struct ICloudBackupService {
    private static let folderName = "WalletBackup"
    private static let fileName = "mnemonic.enc"
    private static let keychainKey = "nuri.wallet.backupKey"

    /// Returns the URL for the backup file inside the user's iCloud container.
    private static func backupFileURL() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            print("❌ [ICloudBackupService] iCloud container unavailable")
            return nil
        }
        let dir = container.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("❌ [ICloudBackupService] Failed to create backup directory: \(error)")
            return nil
        }
        return dir.appendingPathComponent(fileName)
    }

    /// Load or create the symmetric encryption key stored in the user's iCloud keychain.
    /// The key is generated once and synced across devices so the user does not
    /// need to remember a passphrase. The key is stored when the device is
    /// unlocked and is protected by the user's iCloud account.
    private static func loadOrCreateKey() -> SymmetricKey? {
        let keychain = Keychain(service: "com.nuri.iCloudBackup")
            .accessibility(.whenUnlocked)
            .synchronizable(true)

        do {
            if let existing = try keychain.get(keychainKey),
               let data = Data(base64Encoded: existing) {
                print("🔑 [ICloudBackupService] Loaded encryption key from keychain")
                return SymmetricKey(data: data)
            }
        } catch {
            print("❌ [ICloudBackupService] Failed to read key from keychain: \(error)")
        }

        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard result == errSecSuccess else {
            print("❌ [ICloudBackupService] Failed to generate random key")
            return nil
        }
        let encoded = keyData.base64EncodedString()
        do {
            try keychain.set(encoded, key: keychainKey)
            print("✅ [ICloudBackupService] Created new encryption key and stored in iCloud keychain")
        } catch {
            print("❌ [ICloudBackupService] Failed to store key: \(error)")
            return nil
        }
        return SymmetricKey(data: keyData)
    }

    /// Encrypt and save the given mnemonic to iCloud using the automatically
    /// managed encryption key.
    static func backup(mnemonic: String) {
        guard let url = backupFileURL(), let key = loadOrCreateKey() else { return }
        do {
            let sealed = try AES.GCM.seal(Data(mnemonic.utf8), using: key).combined!
            try sealed.write(to: url, options: .atomic)
            print("✅ [ICloudBackupService] Seed backup stored in iCloud: \(url.path)")
        } catch {
            print("❌ [ICloudBackupService] Failed to store backup: \(error)")
        }
    }

    /// Attempt to load and decrypt the mnemonic from iCloud using the stored key.
    static func restore() -> String? {
        guard let url = backupFileURL(), let key = loadOrCreateKey() else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            let phrase = String(data: decrypted, encoding: .utf8)
            print("✅ [ICloudBackupService] Seed backup restored from iCloud")
            return phrase
        } catch {
            print("❌ [ICloudBackupService] Failed to restore backup: \(error)")
            return nil
        }
    }
}
