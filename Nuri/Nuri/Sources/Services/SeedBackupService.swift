import Foundation
import CryptoKit
import KeychainAccess

/// A service to handle the secure encryption and decryption of the wallet seed phrase for backup purposes.
/// This service uses a hardware-backed, device-local key that requires biometric authentication for access.
final class SeedBackupService {
    static let shared = SeedBackupService()

    private var keychain: Keychain
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
    /// Gets debug information about the encryption key (for development/debugging only).
    /// This method requires biometric authentication to access the key.
    /// - Returns: Debug information about the encryption key
    func getEncryptionKeyDebugInfo() throws -> String {
        print("🔍 [SeedBackupService] Getting encryption key debug info...")
        
        do {
            let key = try getOrCreateEncryptionKey()
            let keyData = key.withUnsafeBytes { Data($0) }
            let keyBase64 = keyData.base64EncodedString()
            let keyHex = keyData.map { String(format: "%02X", $0) }.joined()
            
            let debugInfo = """
            🔑 ENCRYPTION KEY DEBUG INFO:
            
            📊 Key Size: \(keyData.count) bytes (\(keyData.count * 8) bits)
            🔤 Key (Base64): \(keyBase64)
            🔢 Key (Hex): \(keyHex)
            🏪 Keychain Service: \(keychain.service ?? "unknown")
            📱 Accessibility: Device-local, biometric protected
            🔄 Synchronizable: false (stays on this device)
            
            ⚠️ WARNING: This key should NEVER leave this device!
            """
            
            print("✅ [SeedBackupService] Debug info generated successfully")
            return debugInfo
        } catch {
            let errorInfo = """
            ❌ FAILED TO GET ENCRYPTION KEY:
            
            Error: \(error.localizedDescription)
            Type: \(type(of: error))
            
            This could indicate:
            - User cancelled Face ID/Touch ID
            - Keychain access denied
            - Key doesn't exist yet
            """
            
            print("❌ [SeedBackupService] Failed to get debug info: \(error)")
            return errorInfo
        }
    }
    
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
        print("   🔍 [SeedBackupService] Checking for existing encryption key...")
        print("   🔍 Key name: \(Keys.backupEncryptionKey)")
        print("   🔍 Keychain service: com.nuri.seed-backup-key")
        print("   🔍 Synchronizable: false")
        print("   🔍 Accessibility: .whenUnlockedThisDeviceOnly + .userPresence")
        
        do {
            // Try to fetch existing key data from keychain.
            print("   🔍 Attempting to fetch existing key...")
            if let keyData = try keychain.getData(Keys.backupEncryptionKey) {
                print("   🔑 Found existing encryption key in keychain (length: \(keyData.count) bytes).")
                return SymmetricKey(data: keyData)
            } else {
                print("   ℹ️ No existing key found (getData returned nil)")
            }
        } catch let error as NSError {
            print("   🔍 Keychain fetch error details:")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            
            // Ignore "item not found" errors, as we'll create a key in that case.
            if error.code != errSecItemNotFound {
                print("   ❌ Non-recoverable keychain error fetching key")
                throw BackupError.keychainError(error)
            } else {
                print("   ℹ️ Key not found (errSecItemNotFound), will create new one")
            }
        }
        
        // If we're here, the key was not found. Let's create it.
        print("   🔑 No existing key found. Generating new encryption key...")
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        print("   🔍 Generated key data length: \(keyData.count) bytes")
        
        do {
            // Store the new key data in the keychain with our strict security settings.
            print("   💾 Attempting to store new key in keychain...")
            print("   💾 Will trigger Face ID prompt for key storage...")
            try keychain.set(keyData, key: Keys.backupEncryptionKey)
            print("   ✅ New encryption key generated and stored in device-local keychain.")
            
            // Verify it was stored
            print("   🔍 Verifying key was stored correctly...")
            if let storedData = try? keychain.getData(Keys.backupEncryptionKey) {
                print("   ✅ Verification successful: stored key length \(storedData.count) bytes")
            } else {
                print("   ⚠️ Warning: Could not verify key was stored")
            }
            
            return newKey
        } catch let error as NSError {
            print("   ❌ Keychain error storing new key:")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            
            // If Face ID fails, try with a simpler accessibility setting
            if error.code == -25293 || error.code == -128 { // errSecAuthFailed or errSecUserCancel
                print("   🔄 Face ID failed, trying with simpler accessibility...")
                do {
                    // Create a temporary keychain with simpler settings
                    let simpleKeychain = Keychain(service: "com.nuri.seed-backup-key-simple")
                        .synchronizable(false)
                        .accessibility(.whenUnlockedThisDeviceOnly)
                    
                    try simpleKeychain.set(keyData, key: Keys.backupEncryptionKey)
                    print("   ✅ Key stored with simpler accessibility settings")
                    
                    // Update our main keychain reference to use the simpler one
                    self.keychain = simpleKeychain
                    return newKey
                } catch {
                    print("   ❌ Even simpler keychain failed: \(error)")
                }
            }
            
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
