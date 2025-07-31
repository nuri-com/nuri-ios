import Foundation
import CryptoKit
import KeychainAccess

/// Service for managing device-specific encryption keys
final class DeviceEncryptionService {
    static let shared = DeviceEncryptionService()
    
    private let keychain = Keychain(service: "com.nuri.device-encryption")
        .accessibility(.whenUnlockedThisDeviceOnly)
        .synchronizable(false) // NEVER sync device keys to iCloud
    
    private let encryptionKeyName = "device.encryption.key"
    
    private init() {
        print("🔐 [DeviceEncryptionService] Initialized")
    }
    
    /// Get or create a device-specific encryption key
    func getOrCreateDeviceKey() throws -> SymmetricKey {
        // Try to retrieve existing key
        if let existingKeyData = try keychain.getData(encryptionKeyName) {
            print("🔐 [DeviceEncryptionService] Found existing device key")
            return SymmetricKey(data: existingKeyData)
        }
        
        // Generate new device-specific key
        print("🔐 [DeviceEncryptionService] Generating new device-specific encryption key...")
        let newKey = SymmetricKey(size: .bits256)
        
        // Store key in local keychain
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try keychain.set(keyData, key: encryptionKeyName)
        
        print("✅ [DeviceEncryptionService] New device key generated and stored")
        return newKey
    }
    
    /// Export the device key as Base64
    func exportDeviceKey() throws -> String {
        guard let keyData = try keychain.getData(encryptionKeyName) else {
            throw EncryptionError.keyNotFound
        }
        
        return keyData.base64EncodedString()
    }
    
    /// Export the device key as hex string
    func exportDeviceKeyAsHex() throws -> String {
        guard let keyData = try keychain.getData(encryptionKeyName) else {
            throw EncryptionError.keyNotFound
        }
        
        return keyData.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Import a device key from Base64
    func importDeviceKey(base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key) else {
            throw EncryptionError.invalidBase64
        }
        
        // Validate key size (should be 32 bytes for 256-bit key)
        guard keyData.count == 32 else {
            throw EncryptionError.invalidKeySize
        }
        
        // Store imported key
        try keychain.set(keyData, key: encryptionKeyName)
        print("✅ [DeviceEncryptionService] Device key imported successfully")
    }
    
    /// Check if device key exists
    func hasDeviceKey() -> Bool {
        do {
            return try keychain.contains(encryptionKeyName)
        } catch {
            return false
        }
    }
    
    /// Encrypt data using device key
    func encrypt(data: String) throws -> String {
        let key = try getOrCreateDeviceKey()
        
        guard let dataToEncrypt = data.data(using: .utf8) else {
            throw EncryptionError.dataConversionFailed
        }
        
        // Encrypt with AES-GCM
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: key)
        
        // Return base64 encoded result
        let encryptedData = sealedBox.combined!
        return encryptedData.base64EncodedString()
    }
    
    /// Decrypt data using device key
    func decrypt(encryptedBase64: String) throws -> String {
        let key = try getOrCreateDeviceKey()
        
        guard let encryptedData = Data(base64Encoded: encryptedBase64) else {
            throw EncryptionError.invalidBase64
        }
        
        // Decrypt with AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.dataConversionFailed
        }
        
        return result
    }
    
    /// Get device key info for display
    func getDeviceKeyInfo() -> String {
        do {
            let keyExists = hasDeviceKey()
            if !keyExists {
                return "No device encryption key found. Will be created on first use."
            }
            
            let keyBase64 = try exportDeviceKey()
            let keyHex = try exportDeviceKeyAsHex()
            
            return """
            🔐 Device Encryption Key Info:
            
            Status: ✅ Active
            Format: 256-bit AES Key
            Storage: Local Keychain Only (No iCloud Sync)
            
            Base64: \(keyBase64.prefix(20))...
            Hex: \(keyHex.prefix(20))...
            
            ⚠️ This key is unique to this device!
            ⚠️ Export and save it to recover your wallet on another device.
            """
        } catch {
            return "Error retrieving device key info: \(error)"
        }
    }
    
    /// Clear device key (for testing only)
    func clearDeviceKey() throws {
        try keychain.remove(encryptionKeyName)
        print("🗑️ [DeviceEncryptionService] Device key cleared")
    }
    
    enum EncryptionError: LocalizedError {
        case keyNotFound
        case dataConversionFailed
        case invalidBase64
        case invalidKeySize
        
        var errorDescription: String? {
            switch self {
            case .keyNotFound:
                return "Device encryption key not found"
            case .dataConversionFailed:
                return "Failed to convert data"
            case .invalidBase64:
                return "Invalid Base64 format"
            case .invalidKeySize:
                return "Invalid key size (must be 256 bits)"
            }
        }
    }
}