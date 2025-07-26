import Foundation
import CryptoKit

/// A per-user AES-GCM encryption helper. The symmetric key is provisioned by the
/// passkey backend after successful authentication/registration and **must** be
/// configured before any encryption/decryption operation is attempted.
///
/// The former test-password workflow is retained as a *no-op* so that existing
/// debug UI continues to compile, but encryption can only proceed once a real
/// key has been set.
final class SimpleEncryptionService {
    static let shared = SimpleEncryptionService()

    // MARK: ‑ Private state
    /// The symmetric AES key supplied by the backend. `nil` until the user has
    /// authenticated with their passkey and the key was delivered.
    private var symmetricKey: SymmetricKey?

    /// Retains the raw base-64 string for optional debugging/diagnostics.
    private var rawKeyBase64: String?

    private init() {
        print("🔐 [SimpleEncryptionService] Initialized – waiting for remote key…")
    }

    // MARK: ‑ Configuration
    /// Configure the service with a base64-encoded key received from the
    /// backend.
    func configure(withBase64Key base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key) else {
            throw EncryptionError.invalidBase64
        }
        guard keyData.count == 32 else {
            print("⚠️ [SimpleEncryptionService] Unexpected key length (expected 32 bytes, got \(keyData.count)) – continuing anyway.")
        }

        self.symmetricKey = SymmetricKey(data: keyData)
        self.rawKeyBase64 = base64Key

        print("✅ [SimpleEncryptionService] Configured with remote AES key (length: \(keyData.count) bytes)")
    }

    /// Indicates whether the service is ready for crypto operations.
    var isConfigured: Bool { symmetricKey != nil }

    // MARK: ‑ Public helpers retained for legacy debug UI
    /// Deprecated – kept so existing debug UI compiles. Always returns a short
    /// description of the current configuration state instead of a password.
    func getCurrentPassword() -> String {
        if let rawKeyBase64 {
            return "<REMOTE AES KEY – \(rawKeyBase64.prefix(8))…>"
        } else {
            return "<NO KEY CONFIGURED>"
        }
    }

    /// Deprecated – no-op retained for source compatibility with `SecurityView`.
    func setPassword(_ newPassword: String) {
        print("⚠️ [SimpleEncryptionService] setPassword(_:) called – ignored. Remote keys are managed automatically.")
    }

    // MARK: ‑ Encryption / Decryption
    func encrypt(data: String) throws -> String {
        guard let key = symmetricKey else {
            throw EncryptionError.keyNotConfigured
        }

        print("🔐 [SimpleEncryptionService] Encrypting data using remote AES key…")

        guard let dataToEncrypt = data.data(using: .utf8) else {
            throw EncryptionError.dataConversionFailed
        }

        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: key)
        let encryptedData = sealedBox.combined!
        let result = encryptedData.base64EncodedString()

        print("   ✅ Data encrypted successfully (cipher length: \(result.count) chars)")

        return result
    }

    func decrypt(encryptedBase64: String) throws -> String {
        guard let key = symmetricKey else {
            throw EncryptionError.keyNotConfigured
        }

        print("🔓 [SimpleEncryptionService] Decrypting data using remote AES key…")

        guard let encryptedData = Data(base64Encoded: encryptedBase64) else {
            throw EncryptionError.invalidBase64
        }

        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        guard let result = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.dataConversionFailed
        }

        print("   ✅ Data decrypted successfully (plain length: \(result.count) chars)")

        return result
    }

    /// Simple round-trip test for debugging.
    func testRoundtrip(testData: String) -> String {
        do {
            let encrypted = try encrypt(data: testData)
            let decrypted = try decrypt(encryptedBase64: encrypted)
            let matches = (testData == decrypted)
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

    // MARK: ‑ Error types
    enum EncryptionError: Error {
        case dataConversionFailed
        case invalidBase64
        case keyNotConfigured
    }
}