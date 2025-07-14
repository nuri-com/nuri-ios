import Foundation
import CryptoKit

/// Simple password-based encryption for testing
final class SimpleEncryptionService {
    static let shared = SimpleEncryptionService()
    
    // EDITABLE PASSWORD FOR TESTING - can be changed via security screen
    private var testPassword = "nuri-test-password-2024"
    
    private init() {
        print("🔐 [SimpleEncryptionService] Initialized with test password: \(testPassword)")
    }
    
    /// Get current password for display/editing
    func getCurrentPassword() -> String {
        return testPassword
    }
    
    /// Set new password for testing
    func setPassword(_ newPassword: String) {
        print("🔐 [SimpleEncryptionService] Password changed from '\(testPassword)' to '\(newPassword)'")
        testPassword = newPassword
    }
    
    /// Encrypt data using hardcoded password
    func encrypt(data: String) throws -> String {
        print("🔐 [SimpleEncryptionService] Encrypting data with test password...")
        
        guard let dataToEncrypt = data.data(using: .utf8) else {
            throw EncryptionError.dataConversionFailed
        }
        
        // Derive key from password
        let key = deriveKey(from: testPassword)
        
        // Encrypt with AES-GCM
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: key)
        
        // Return base64 encoded result
        let encryptedData = sealedBox.combined!
        let result = encryptedData.base64EncodedString()
        
        print("   ✅ Data encrypted successfully")
        print("   📝 Input length: \(data.count) chars")
        print("   📝 Output length: \(result.count) chars")
        
        return result
    }
    
    /// Decrypt data using hardcoded password
    func decrypt(encryptedBase64: String) throws -> String {
        print("🔓 [SimpleEncryptionService] Decrypting data with test password...")
        
        guard let encryptedData = Data(base64Encoded: encryptedBase64) else {
            throw EncryptionError.invalidBase64
        }
        
        // Derive same key from password
        let key = deriveKey(from: testPassword)
        
        // Decrypt with AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.dataConversionFailed
        }
        
        print("   ✅ Data decrypted successfully")
        print("   📝 Input length: \(encryptedBase64.count) chars")
        print("   📝 Output length: \(result.count) chars")
        
        return result
    }
    
    /// Test encryption/decryption roundtrip
    func testRoundtrip(testData: String) -> String {
        print("🧪 [SimpleEncryptionService] Testing encryption roundtrip...")
        
        do {
            // Encrypt
            let encrypted = try encrypt(data: testData)
            print("   ✅ Encryption successful")
            
            // Decrypt
            let decrypted = try decrypt(encryptedBase64: encrypted)
            print("   ✅ Decryption successful")
            
            // Verify
            let matches = testData == decrypted
            print("   🔍 Data matches: \(matches)")
            
            return """
            🧪 ENCRYPTION ROUNDTRIP TEST:
            
            ✅ Original: \(testData)
            🔐 Encrypted: \(encrypted.prefix(50))...
            🔓 Decrypted: \(decrypted)
            🎯 Match: \(matches ? "✅ SUCCESS" : "❌ FAILED")
            """
            
        } catch {
            return "❌ Roundtrip test failed: \(error)"
        }
    }
    
    private func deriveKey(from password: String) -> SymmetricKey {
        // Simple key derivation from password
        // In production, use PBKDF2 or similar
        let data = password.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return SymmetricKey(data: hash)
    }
    
    enum EncryptionError: Error {
        case dataConversionFailed
        case invalidBase64
    }
}