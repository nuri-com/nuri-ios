import Foundation
import CryptoKit
import KeychainAccess

/// A service to handle the secure encryption and decryption of the wallet seed phrase for backup purposes.
/// This service uses a hardware-backed, device-local key that requires biometric authentication for access.
final class SeedBackupService {
    static let shared = SeedBackupService()

    private let keychain: Keychain
    private enum Keys {
        // This key is for the encryption key itself, NOT the seed phrase.
        // It's stored securely and NEVER leaves the device.
        static let backupEncryptionKey = "com.nuri.backup.encryptionKey"
    }

    private init() {
        // Configure keychain access for the encryption key.
        // CRITICAL: .synchronizable(false) ensures this key NEVER goes to iCloud.
        // .accessibility(.whenUnlockedThisDeviceOnly) with .userPresence ensures
        // the key is only accessible after biometric authentication on this specific device.
        self.keychain = Keychain(service: "com.nuri.seed-backup-key")
            .synchronizable(false)
            .accessibility(.whenUnlockedThisDeviceOnly, authenticationPolicy: .userPresence)
        
        print("🔑 [SeedBackupService] Initialized with device-local, biometric-protected keychain.")
    }

    // MARK: - Public API

    /// Encrypts the seed phrase using a device-local, biometrically-protected key.
    /// - Parameter seedPhrase: The 12 or 24-word mnemonic to encrypt.
    /// - Returns: A Base64-encoded string representing the encrypted data, safe for storage.
    /// - Throws: An error if encryption fails, which could be due to keychain access issues
    ///           (e.g., user cancelling biometric prompt).
    func encrypt(seedPhrase: String) throws -> String {
        print("🔐 [SeedBackupService] Starting seed phrase encryption...")
        
        let key = try getOrCreateEncryptionKey()
        print("   ✅ Fetched encryption key (biometrics likely required).")
        
        guard let dataToEncrypt = seedPhrase.data(using: .utf8) else {
            print("   ❌ Error: Could not convert seed phrase to data.")
            throw BackupError.dataConversionFailed
        }
        
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: key)
        print("   ✅ Seed phrase encrypted successfully using AES.GCM.")
        
        // The combined representation includes the nonce, encrypted data, and authentication tag.
        let encryptedData = sealedBox.combined!
        let base64String = encryptedData.base64EncodedString()
        print("   ✅ Encrypted data converted to Base64 string.")
        
        return base64String
    }

    /// Decrypts a backup string to recover the original seed phrase.
    /// - Parameter backupString: The Base64-encoded string from a backup file.
    /// - Returns: The original seed phrase.
    /// - Throws: An error if decryption fails, which could be due to a wrong key,
    ///           tampered data, or user cancelling biometric prompt.
    func decrypt(backupString: String) throws -> String {
        print("🔓 [SeedBackupService] Starting seed phrase decryption...")

        guard let encryptedData = Data(base64Encoded: backupString) else {
            print("   ❌ Error: Invalid Base64 string.")
            throw BackupError.invalidBase64String
        }

        let key = try getOrCreateEncryptionKey()
        print("   ✅ Fetched encryption key (biometrics likely required).")

        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        print("   ✅ Parsed sealed box from backup data.")

        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        print("   ✅ Successfully decrypted data using AES.GCM.")

        guard let seedPhrase = String(data: decryptedData, encoding: .utf8) else {
            print("   ❌ Error: Could not convert decrypted data to string.")
            throw BackupError.dataConversionFailed
        }
        
        print("   ✅ Decryption complete. Recovered seed phrase.")
        return seedPhrase
    }

    // MARK: - Private Helpers

    /// Fetches the encryption key from the device-local keychain. If it doesn't exist,
    /// it creates a new one and stores it securely.
    /// This operation will trigger a biometric prompt for the user.
    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        do {
            // Try to fetch existing key data from keychain.
            if let keyData = try keychain.getData(Keys.backupEncryptionKey) {
                print("   🔑 Found existing encryption key in keychain.")
                return SymmetricKey(data: keyData)
            }
        } catch let error as NSError {
            // Ignore "item not found" errors, as we'll create a key in that case.
            if error.code != errSecItemNotFound {
                print("   ❌ Keychain error fetching key: \(error.localizedDescription)")
                throw BackupError.keychainError(error)
            }
        }
        
        // If we're here, the key was not found. Let's create it.
        print("   🔑 No existing key found. Generating new encryption key...")
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        do {
            // Store the new key data in the keychain with our strict security settings.
            try keychain.set(keyData, key: Keys.backupEncryptionKey)
            print("   ✅ New encryption key generated and stored in device-local keychain.")
            return newKey
        } catch let error as NSError {
            print("   ❌ Keychain error storing new key: \(error.localizedDescription)")
            throw BackupError.keychainError(error)
        }
    }

    enum BackupError: Error, LocalizedError {
        case keychainError(NSError)
        case dataConversionFailed
        case invalidBase64String

        var errorDescription: String? {
            switch self {
            case .keychainError(let error):
                // You could provide more user-friendly messages for common errors like user cancellation.
                if error.code == errSecUserCanceled {
                    return "Authentication was cancelled."
                }
                return "A secure storage error occurred: \(error.localizedDescription)"
            case .dataConversionFailed:
                return "Failed to handle backup data."
            case .invalidBase64String:
                return "The backup data is not in a valid format."
            }
        }
    }
}
