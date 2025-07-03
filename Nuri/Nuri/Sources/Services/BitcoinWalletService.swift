import Foundation
import BitcoinDevKit
import KeychainAccess
import LocalAuthentication
import Security

final class BitcoinWalletService {
    static let shared = BitcoinWalletService()

    // MARK: - Constants
    private let network: Network = .bitcoin // mainnet
    private var keychain: Keychain?
    private var currentUserID: String?
    private enum Keys {
        static let mnemonic = "nuri.wallet.mnemonic"
        static let descriptor = "nuri.wallet.descriptor"
        static let changeDescriptor = "nuri.wallet.changeDescriptor"
        static let currentAddress = "nuri.wallet.currentAddress"
    }
    
    // MARK: - Error Types
    private enum WalletError: Error {
        case noExistingWallet
        case keychainAccessFailed
        case walletCorrupted
    }

    // MARK: - In-memory state
    private var wallet: Wallet?
    private var connection: Connection?
    private var currentBitcoinAddress: String?

    private init() {
        print("🔑 [BitcoinWalletService] Initializing wallet service...")
        // Wallet initialization will happen when user ID is available
    }

    // MARK: - Public API
    func currentAddress() -> String? {
        // Return cached address if available
        if let cachedAddress = currentBitcoinAddress {
            return cachedAddress
        }
        
        // Try to load cached address from keychain first
        if let keychainAddress = loadAddressFromKeychain() {
            currentBitcoinAddress = keychainAddress
            print("🔑 [BitcoinWalletService] Loaded address from keychain: \(keychainAddress)")
            return keychainAddress
        }
        
        // Only generate new address if no cached address exists and wallet is available
        guard let wallet else { return nil }
        let info = wallet.revealNextAddress(keychain: .external)
        currentBitcoinAddress = info.address.description
        saveAddressToKeychain(currentBitcoinAddress!)
        persist()
        print("🔑 [BitcoinWalletService] Generated and cached new address: \(currentBitcoinAddress!)")
        return currentBitcoinAddress
    }

    func seedPhrase() -> String? {
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Cannot retrieve seed phrase - keychain not initialized")
            return nil
        }
        print("🔐 [BitcoinWalletService] About to retrieve mnemonic from keychain...")
        do {
            let phrase = try keychain.get(Keys.mnemonic)
            if let phrase = phrase {
                print("✅ [BitcoinWalletService] Retrieved mnemonic from keychain (length: \(phrase.count))")
            } else {
                print("ℹ️ [BitcoinWalletService] Mnemonic not found in keychain")
            }
            return phrase
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to retrieve mnemonic: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            return nil
        }
    }
    
    func retryWalletLoad() {
        guard wallet == nil else { return }
        initialiseWallet()
    }
    
    func hasWallet() -> Bool {
        return wallet != nil
    }
    
    func forceCreateNewWallet() {
        print("⚠️ [BitcoinWalletService] Force creating new wallet")
        createAndStoreWallet()
    }
    
    /// Initialize wallet for a specific user ID (from Privy)
    func initializeForUser(_ userID: String) {
        print("🔑 [BitcoinWalletService] Initializing wallet for user: \(userID)")
        currentUserID = userID
        setupKeychain(for: userID)
        initialiseWallet()
    }
    
    private func setupKeychain(for userID: String) {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.nuri.wallet"
        // Sanitize user ID for keychain service name (remove colons and special characters)
        let sanitizedUserID = userID.replacingOccurrences(of: ":", with: "-")
                                   .replacingOccurrences(of: " ", with: "")
        let keychainService = "\(bundleId).\(sanitizedUserID)"
        print("🔑 [BitcoinWalletService] Setting up keychain for service: \(keychainService)")
        print("🔑 [BitcoinWalletService] Original user ID: \(userID)")
        print("🔑 [BitcoinWalletService] Sanitized user ID: \(sanitizedUserID)")
        print("🔑 [BitcoinWalletService] Bundle ID: \(bundleId)")
        print("🔑 [BitcoinWalletService] Final keychain service: \(keychainService)")
        
        // Check biometric availability
        let context = LAContext()
        var error: NSError?
        let biometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if biometricAvailable {
            print("✅ [BitcoinWalletService] Biometric authentication available")
            let biometryType = context.biometryType
            switch biometryType {
            case .faceID:
                print("   👤 Face ID available")
            case .touchID:
                print("   👆 Touch ID available")
            case .opticID:
                print("   👁️ Optic ID available")
            default:
                print("   🔐 Biometric type: \(biometryType.rawValue)")
            }
        } else {
            print("❌ [BitcoinWalletService] Biometric authentication NOT available")
            if let error = error {
                print("   📋 Error: \(error.localizedDescription)")
            }
        }
        
        // Create user-specific keychain with biometric authentication
        // NOTE: `synchronizable` cannot be combined with `authenticationPolicy`
        // so iCloud sync is disabled when biometrics are required.
        keychain = Keychain(service: keychainService)
            .accessibility(
                .whenUnlocked,
                authenticationPolicy: .biometryAny
            )
            .synchronizable(false)
            .authenticationPrompt("Access your Bitcoin wallet")

        print("🔑 [BitcoinWalletService] Keychain configured:")
        print("   🌩️ iCloud sync: DISABLED")
        print("   🔐 Biometric auth: REQUIRED (.biometryAny)")
        print("   🔓 Accessibility: .whenUnlocked")
        print("   💬 Prompt: 'Access your Bitcoin wallet'")
    }

    // MARK: - Private helpers
    private func initialiseWallet() {
        print("🚀 [BitcoinWalletService] initialiseWallet() called")
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Keychain not initialized - call initializeForUser first")
            return
        }
        print("✅ [BitcoinWalletService] Keychain is initialized, proceeding with wallet initialization")
        
        // Try to load existing wallet with single keychain access attempt
        do {
            try loadExistingWallet()
            print("✅ [BitcoinWalletService] Existing wallet loaded successfully")
        } catch WalletError.noExistingWallet {
            print("ℹ️ [BitcoinWalletService] No existing wallet found, creating new one")
            createAndStoreWallet()
        } catch WalletError.keychainAccessFailed {
            print("❌ [BitcoinWalletService] Keychain access failed - may need biometric auth")
            // Don't create new wallet immediately, wait for explicit user action
        } catch {
            print("⚠️ [BitcoinWalletService] Failed to load existing wallet: \(error)")
            // Only create new wallet if we're certain the existing one is corrupted
            createAndStoreWallet()
        }
    }
    
    private func loadExistingWallet() throws {
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Keychain not initialized")
            throw WalletError.keychainAccessFailed
        }
        
        print("🔍 [BitcoinWalletService] Attempting to load existing wallet from keychain...")
        
        // Try to get mnemonic with detailed error reporting and biometric auth
        print("🔐 [BitcoinWalletService] About to request mnemonic from keychain (will trigger Face ID)...")
        do {
            let mnemonic = try keychain.get(Keys.mnemonic)
            if let mnemonic = mnemonic {
                print("✅ [BitcoinWalletService] Found mnemonic in keychain after biometric auth (length: \(mnemonic.count))")
            } else {
                print("❌ [BitcoinWalletService] Mnemonic key exists but value is nil")
                throw WalletError.noExistingWallet
            }
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to get mnemonic from keychain: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            if error.domain == "com.kishikawakatsumi.KeychainAccess.error" {
                print("   📋 KeychainAccess specific error - possibly biometric auth failed")
            }
            throw WalletError.noExistingWallet
        }
        
        // Try to get descriptors with biometric auth
        print("🔐 [BitcoinWalletService] About to request descriptors from keychain (may trigger Face ID again)...")
        do {
            let descriptor = try keychain.get(Keys.descriptor)
            let changeDescriptor = try keychain.get(Keys.changeDescriptor)
            
            guard let descriptor = descriptor, let changeDescriptor = changeDescriptor else {
                print("❌ [BitcoinWalletService] Mnemonic found but descriptors missing")
                throw WalletError.walletCorrupted
            }
            
            print("✅ [BitcoinWalletService] Found descriptors in keychain after biometric auth")
            print("   📝 External descriptor length: \(descriptor.count)")
            print("   📝 Internal descriptor length: \(changeDescriptor.count)")
            print("   📝 External descriptor preview: \(String(descriptor.prefix(50)))...")
            print("   📝 Internal descriptor preview: \(String(changeDescriptor.prefix(50)))...")
            
            // Load wallet with existing descriptors
            print("🔧 [BitcoinWalletService] About to load wallet with existing descriptors...")
            try loadWallet(descriptor: descriptor, changeDescriptor: changeDescriptor)
            print("✅ [BitcoinWalletService] Wallet loaded successfully from descriptors")
            
            // Load cached address from keychain (don't generate new one)
            if let cachedAddress = loadAddressFromKeychain() {
                currentBitcoinAddress = cachedAddress
                print("🔑 [BitcoinWalletService] Existing wallet loaded, cached address restored: \(cachedAddress)")
            } else {
                // Only generate address if no cached address exists
                if let wallet = self.wallet {
                    let addressInfo = wallet.revealNextAddress(keychain: .external)
                    currentBitcoinAddress = addressInfo.address.description
                    saveAddressToKeychain(currentBitcoinAddress!)
                    persist()
                    print("🔑 [BitcoinWalletService] Existing wallet loaded, first address generated: \(currentBitcoinAddress!)")
                }
            }
            
            print("✅ [BitcoinWalletService] Wallet successfully loaded from keychain for user: \(currentUserID ?? "unknown")")
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to load descriptors or wallet: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            throw error
        }
    }

    private func walletDBPath() throws -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("wallet_data")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("wallet.sqlite").path
    }

    private func loadWallet(descriptor: String, changeDescriptor: String) throws {
        print("🔧 [BitcoinWalletService] loadWallet() called")
        print("   📝 Descriptor length: \(descriptor.count)")
        print("   📝 Change descriptor length: \(changeDescriptor.count)")
        
        let dbPath = try walletDBPath()
        print("   📋 Database path: \(dbPath)")
        
        do {
            let conn = try Connection(path: dbPath)
            print("   ✅ Database connection established")
            
            let desc = try Descriptor(descriptor: descriptor, network: network)
            print("   ✅ External descriptor parsed successfully")
            
            let changeDesc = try Descriptor(descriptor: changeDescriptor, network: network)
            print("   ✅ Internal descriptor parsed successfully")
            
            self.wallet = try Wallet.load(descriptor: desc, changeDescriptor: changeDesc, connection: conn)
            self.connection = conn
            print("   ✅ Wallet loaded successfully from database")
        } catch let error as NSError {
            print("   ❌ Failed to load wallet: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            throw error
        }
    }

    private func createAndStoreWallet() {
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Keychain not initialized")
            return
        }
        
        do {
            print("🔧 [BitcoinWalletService] Creating new wallet for user: \(currentUserID ?? "unknown")")
            let mnemonic = Mnemonic(wordCount: .words12)
            let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonic, password: nil)
            let externalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network)
            let internalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network)

            print("🔐 [BitcoinWalletService] Storing wallet to user-specific keychain (will trigger Face ID for backup)...")
            
            // Store to keychain with biometric authentication
            print("   🔐 About to store mnemonic to keychain...")
            try keychain.set(mnemonic.description, key: Keys.mnemonic)
            print("   ✅ Mnemonic stored successfully")
            // Verify mnemonic was stored correctly
            verifyMnemonicStored()
            
            print("   🔐 About to store external descriptor to keychain...")
            try keychain.set(externalDesc.toStringWithSecret(), key: Keys.descriptor)
            print("   ✅ External descriptor stored successfully")
            
            print("   🔐 About to store internal descriptor to keychain...")
            try keychain.set(internalDesc.toStringWithSecret(), key: Keys.changeDescriptor)
            print("   ✅ Internal descriptor stored successfully")
            
            // Keychain configuration summary
            print("   🌍 Keychain configured with iCloud sync disabled")
            print("   🔐 Biometric authentication required for access")

            // Create wallet DB & instance
            let dbPath = try walletDBPath()
            print("🗄️ [BitcoinWalletService] Creating wallet DB at: \(dbPath)")
            let conn = try Connection(path: dbPath)
            let wallet = try Wallet(descriptor: externalDesc, changeDescriptor: internalDesc, network: network, connection: conn)
            self.wallet = wallet
            self.connection = conn
            
            // Generate and cache the first address
            let addressInfo = wallet.revealNextAddress(keychain: .external)
            currentBitcoinAddress = addressInfo.address.description
            saveAddressToKeychain(currentBitcoinAddress!)
            persist()
            
            print("✅ [BitcoinWalletService] New wallet created and stored successfully for user: \(currentUserID ?? "unknown")")
            print("🔑 [BitcoinWalletService] First address cached: \(currentBitcoinAddress!)")
        } catch {
            print("❌ [BitcoinWalletService] Wallet creation failed: \(error)")
        }
    }

    private func persist() {
        guard let wallet, let connection else { return }
        do {
            _ = try wallet.persist(connection: connection)
        } catch {
            print("⚠️ Persist error: \(error)")
        }
    }
    
    // MARK: - Address Keychain Helpers
    private func saveAddressToKeychain(_ address: String) {
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Cannot save address - keychain not initialized")
            return
        }
        
        print("🔐 [BitcoinWalletService] About to save address to keychain (may trigger Face ID)...")
        do {
            try keychain.set(address, key: Keys.currentAddress)
            print("✅ [BitcoinWalletService] Address saved to keychain with biometric protection: \(address)")
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to save address to keychain: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
        }
    }
    
    private func loadAddressFromKeychain() -> String? {
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Cannot load address - keychain not initialized")
            return nil
        }
        
        print("🔐 [BitcoinWalletService] About to load address from keychain (will trigger Face ID)...")
        do {
            let address = try keychain.get(Keys.currentAddress)
            if let address = address {
                print("✅ [BitcoinWalletService] Address loaded from keychain after biometric auth: \(address)")
            } else {
                print("ℹ️ [BitcoinWalletService] No address found in keychain")
            }
            return address
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to load address from keychain: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            if error.code == -128 {
                print("   🙅 User cancelled biometric authentication")
            } else if error.code == -25300 {
                print("   🔍 Item not found in keychain")
            }
            return nil
        }
    }

    // MARK: - Mnemonic Verification Helper
private func verifyMnemonicStored() {
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Cannot verify mnemonic - keychain not initialized")
            return
        }
        print("🔐 [BitcoinWalletService] Verifying mnemonic was stored...")
        do {
            let value = try keychain.get(Keys.mnemonic)
            if let value = value {
                print("✅ [BitcoinWalletService] Mnemonic verified in keychain (length: \(value.count))")
            } else {
                print("❌ [BitcoinWalletService] Mnemonic missing after attempted store")
            }
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to verify mnemonic in keychain: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
        }
    }

    // MARK: - Balance
    /// Syncs the wallet with the blockchain and returns the total balance in satoshis.
    func syncAndGetBalance() async -> UInt64? {
        guard let wallet else { return nil }
        do {
            let esploraConfig = EsploraConfig(baseURL: "https://blockstream.info/api")
            let blockchain = try Blockchain(config: .esplora(esploraConfig))
            try wallet.sync(blockchain: blockchain, progress: nil)
            let bal = try wallet.getBalance()
            return bal.total
        } catch {
            print("❌ [BitcoinWalletService] Failed to sync and get balance: \(error)")
            return nil
        }
    }
}
