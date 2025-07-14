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
    private var backupKeychain: Keychain?
    private var currentUserID: String?
    private var esploraClient: EsploraClient?
    private enum Keys {
        static let mnemonic = "bitcoin.wallet.mnemonic"
        static let currentAddress = "bitcoin.wallet.currentAddress"
        static let encryptedMnemonicBackup = "bitcoin.wallet.encryptedMnemonicBackup"
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
        // Initialize Esplora client for mainnet
        self.esploraClient = EsploraClient(url: "https://blockstream.info/api")
        // Wallet initialization will happen when user ID is available
    }

    // MARK: - Public API
    func currentAddress() -> String? {
        print("🔍 [BitcoinWalletService] currentAddress() called")
        // Return cached address if available
        if let cachedAddress = currentBitcoinAddress {
            print("✅ [BitcoinWalletService] Returning cached address (no Face ID): \(cachedAddress)")
            return cachedAddress
        }
        
        print("⚠️ [BitcoinWalletService] No cached address, will try keychain...")
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
        print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #2 - seedPhrase() method called...")
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
        let hasWallet = wallet != nil
        print("🔍 [BitcoinWalletService] hasWallet() called - result: \(hasWallet)")
        return hasWallet
    }
    
    /// Get the current wallet instance (for transaction operations)
    func getWallet() -> Wallet? {
        return wallet
    }
    
    /// Get the current esplora client (for transaction broadcasting)
    func getEsploraClient() -> EsploraClient? {
        return esploraClient
    }
    
    func forceCreateNewWallet() {
        print("⚠️ [BitcoinWalletService] Force creating new wallet")
        createAndStoreWallet()
    }
    
    /// Force a full blockchain rescan
    func forceFullRescan() async -> Bool {
        print("🔄 [BitcoinWalletService] Force full rescan requested")
        guard let wallet else { 
            print("❌ [BitcoinWalletService] No wallet available for rescan")
            return false
        }
        guard let esploraClient else { 
            print("❌ [BitcoinWalletService] No esplora client available for rescan")
            return false
        }
        
        do {
            print("🔍 [BitcoinWalletService] Starting FULL SCAN (not just revealed addresses)...")
            
            // Use startFullScan instead of startSyncWithRevealedSpks
            let inspector = WalletSyncScriptInspector { inspected, total in
                print("🔄 [BitcoinWalletService] Full scan progress: \(inspected)/\(total)")
            }
            
            // To do a "full scan", we need to reveal more addresses first
            print("🔍 [BitcoinWalletService] Revealing addresses for full scan...")
            
            // Reveal many addresses to ensure we find all transactions
            for i in 0..<100 {
                let addr = wallet.revealNextAddress(keychain: .external)
                if i % 10 == 0 {
                    print("   📍 Address \(i): \(addr.address.description)")
                }
            }
            
            // Now sync with all revealed addresses
            let syncRequest = try wallet.startSyncWithRevealedSpks()
                .inspectSpks(inspector: inspector)
                .build()
            
            print("📡 [BitcoinWalletService] Starting full blockchain scan...")
            let update = try esploraClient.sync(
                request: syncRequest,
                parallelRequests: UInt64(10) // More parallel requests for faster scan
            )
            
            try wallet.applyUpdate(update: update)
            persist()
            
            // Log results
            let balance = wallet.balance()
            let txCount = wallet.transactions().count
            print("✅ [BitcoinWalletService] Full scan completed:")
            print("   💰 Balance: \(balance.confirmed.toSat()) confirmed sats")
            print("   📋 Transactions found: \(txCount)")
            
            return true
        } catch {
            print("❌ [BitcoinWalletService] Full scan failed: \(error)")
            return false
        }
    }
    
    /// Initialize wallet automatically when app starts (no user ID required)
    func initializeWalletOnAppStart() {
        print("🔑 [BitcoinWalletService] 🚨 initializeWalletOnAppStart() called")
        
        // Check if we're already initialized
        if wallet != nil {
            print("✅ [BitcoinWalletService] Wallet already initialized, skipping...")
            return
        }
        
        // Use a default user ID for wallet initialization
        let defaultUserID = "default-user"
        print("🔄 [BitcoinWalletService] Proceeding with initialization for default user...")
        currentUserID = defaultUserID
        setupKeychain(for: defaultUserID)
        initialiseWallet()
    }
    
    /// Initialize wallet for a specific user ID
    func initializeForUser(_ userID: String) {
        print("🔑 [BitcoinWalletService] 🚨 initializeForUser() called for user: \(userID)")
        
        // Check if we're already initialized for this user
        if currentUserID == userID && wallet != nil {
            print("✅ [BitcoinWalletService] Already initialized for this user, skipping...")
            return
        }
        
        print("🔄 [BitcoinWalletService] Proceeding with initialization...")
        currentUserID = userID
        setupKeychain(for: userID)
        initialiseWallet()
    }
    
    private func setupKeychain(for userID: String) {
        // Use a single, consistent keychain service for all wallet operations
        // This prevents creating multiple keychain entries
        let keychainService = "com.nuri.bitcoin-wallet"
        print("🔑 [BitcoinWalletService] Setting up keychain")
        print("🔑 [BitcoinWalletService] Keychain service: \(keychainService)")
        print("🔑 [BitcoinWalletService] User ID: \(userID)")
        
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
        
        // Create keychain with highest security settings.
        // The seed will ONLY be stored on this device and will require
        // biometric authentication (Face ID/Touch ID) for every access.
        keychain = Keychain(service: keychainService)
            .synchronizable(false) // DO NOT sync seed via iCloud
            .accessibility(.whenUnlockedThisDeviceOnly, authenticationPolicy: .userPresence)
        
        // This keychain is SEPARATE and ONLY for the encrypted backup. It's OK to sync.
        backupKeychain = Keychain(service: "com.nuri.bitcoin-wallet.backup")
            .synchronizable(true)
            .accessibility(.afterFirstUnlock) // No biometric check on the encrypted data itself.

        print("🔑 [BitcoinWalletService] Keychain configured:")
        print("   (Local Seed) 🌩️ iCloud sync: DISABLED for security")
        print("   (Local Seed) 🔓 Accessibility: .whenUnlockedThisDeviceOnly")
        print("   (Local Seed) 📱 Authentication: .userPresence")
        print("   (Backup)     ☁️ iCloud sync: ENABLED for encrypted backup")
    }

    // MARK: - Private helpers
    private func initialiseWallet() {
        print("🚀 [BitcoinWalletService] initialiseWallet() called")
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Keychain not initialized - call initializeForUser first")
            return
        }
        print("✅ [BitcoinWalletService] Keychain is initialized, proceeding with wallet initialization")
        
        // Try to load existing wallet with SINGLE Face ID prompt
        do {
            try loadExistingWalletWithSingleAuth()
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
        var mnemonicStr: String?
        do {
            mnemonicStr = try keychain.get(Keys.mnemonic)
            if let mnemonic = mnemonicStr {
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
        
        // Always regenerate descriptors from mnemonic instead of storing them
        print("🔧 [BitcoinWalletService] Regenerating descriptors from mnemonic...")
        guard let mnemonicString = mnemonicStr else {
            throw WalletError.noExistingWallet
        }
        
        let mnemonicObj = try Mnemonic.fromString(mnemonic: mnemonicString)
        let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonicObj, password: nil)
        let descriptor = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network).toStringWithSecret()
        let changeDescriptor = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network).toStringWithSecret()
        print("✅ [BitcoinWalletService] Descriptors regenerated successfully")
        
        // Clean up any old descriptor entries from previous versions
        print("🧹 [BitcoinWalletService] Cleaning up old descriptor entries...")
        try? keychain.remove("nuri.wallet.descriptor")
        try? keychain.remove("nuri.wallet.changeDescriptor")
        
        // Load wallet with regenerated descriptors
        print("🔧 [BitcoinWalletService] Loading wallet with regenerated descriptors...")
        try loadWallet(descriptor: descriptor, changeDescriptor: changeDescriptor)
        print("✅ [BitcoinWalletService] Wallet loaded successfully from regenerated descriptors")
        
        // Load cached address from keychain (don't generate new one)
        if let cachedAddress = loadAddressFromKeychain() {
            currentBitcoinAddress = cachedAddress
            print("🔑 [BitcoinWalletService] Existing wallet loaded, cached address restored: \(cachedAddress)")
            
            // Verify this is the expected address
            if cachedAddress == "bc1p66fmpw0eck2wu6cml7x5mj8vnesq9vkcg5qxvkcpnx3d775gwu8q60v9sx" {
                print("✅ [BitcoinWalletService] This is the expected address with 14 transactions!")
            } else {
                print("⚠️ [BitcoinWalletService] Different address than expected")
            }
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
        
        // CRITICAL: Check if seed already exists - NEVER overwrite
        do {
            if let existingSeed = try keychain.get(Keys.mnemonic) {
                print("🚫 [BitcoinWalletService] SEED ALREADY EXISTS - WILL NOT CREATE NEW WALLET")
                print("🔄 [BitcoinWalletService] Recovering from existing seed instead...")
                
                // Recover from existing seed
                let mnemonicObj = try Mnemonic.fromString(mnemonic: existingSeed)
                let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonicObj, password: nil)
                let externalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network)
                let internalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network)
                
                // Create wallet from existing seed
                let dbPath = try walletDBPath()
                let conn = try Connection(path: dbPath)
                let wallet = try Wallet(descriptor: externalDesc, changeDescriptor: internalDesc, network: network, connection: conn)
                self.wallet = wallet
                self.connection = conn
                
                // Load or generate address
                if let cachedAddress = loadAddressFromKeychain() {
                    currentBitcoinAddress = cachedAddress
                    print("🔑 [BitcoinWalletService] Recovered wallet with cached address: \(cachedAddress)")
                } else {
                    let addressInfo = wallet.revealNextAddress(keychain: .external)
                    currentBitcoinAddress = addressInfo.address.description
                    saveAddressToKeychain(currentBitcoinAddress!)
                    persist()
                    print("🔑 [BitcoinWalletService] Recovered wallet, generated first address: \(currentBitcoinAddress!)")
                }
                
                print("✅ [BitcoinWalletService] Successfully recovered existing wallet")
                return
            }
        } catch {
            print("ℹ️ [BitcoinWalletService] No existing seed found, proceeding to create new wallet")
        }
        
        do {
            print("🔧 [BitcoinWalletService] Creating NEW wallet for user: \(currentUserID ?? "unknown")")
            let mnemonic = Mnemonic(wordCount: .words12)
            let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonic, password: nil)
            let externalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network)
            let internalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network)

            print("🔐 [BitcoinWalletService] Storing NEW mnemonic to keychain...")
            
            // Double-check we're not overwriting
            if try keychain.contains(Keys.mnemonic) {
                print("🚫 [BitcoinWalletService] CRITICAL: Seed already exists! Aborting creation.")
                throw WalletError.walletCorrupted
            }
            
            // Store ONLY the mnemonic to keychain
            print("🔐 [BitcoinWalletService] Storing mnemonic to iCloud keychain...")
            try keychain.set(mnemonic.description, key: Keys.mnemonic)
            print("   ✅ NEW mnemonic stored successfully to LOCAL keychain.")

            // Also create an encrypted backup and store it in iCloud Keychain.
            // This runs in the background so it doesn't slow down wallet creation.
            Task {
                await self.createEncryptedBackup(for: mnemonic.description)
            }
            
            // Clean up any old descriptor entries from previous versions
            print("🧹 [BitcoinWalletService] Cleaning up any existing descriptor entries...")
            try? keychain.remove("nuri.wallet.descriptor")
            try? keychain.remove("nuri.wallet.changeDescriptor")
            print("   ✅ Descriptor entries cleaned up")
            
            // Verify mnemonic was stored correctly
            verifyMnemonicStored()
            
            // Keychain configuration summary
            print("   🌍 Keychain configured with iCloud sync")
            print("   📝 Only mnemonic stored (descriptors regenerated on load)")
            print("   ✅ This reduces keychain entries from 3 to 1")

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
        
        print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #3 - saveAddressToKeychain() called...")
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
        
        print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #4 - loadAddressFromKeychain() called...")
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
        print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #5 - verifyMnemonicStored() called...")
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
        guard let wallet else { 
            print("❌ [BitcoinWalletService] No wallet available for balance sync")
            return nil 
        }
        
        guard let esploraClient else {
            print("❌ [BitcoinWalletService] No Esplora client available for sync")
            return nil
        }
        
        do {
            print("🔄 [BitcoinWalletService] Starting wallet sync with blockchain...")
            
            // Sync wallet with blockchain using correct BDK API
            try await syncWallet()
            print("✅ [BitcoinWalletService] Wallet sync completed")
            
            // Get updated balance
            let balance = wallet.balance()
            let totalSats = balance.total.toSat()
            let confirmedSats = balance.confirmed.toSat()
            let pendingSats = balance.trustedPending.toSat() + balance.untrustedPending.toSat()
            
            print("💰 [BitcoinWalletService] Balance updated:")
            print("   📊 Total: \(totalSats) sats")
            print("   ✅ Confirmed: \(confirmedSats) sats")
            print("   ⏳ Pending: \(pendingSats) sats")
            
            return totalSats
        } catch {
            print("❌ [BitcoinWalletService] Failed to sync wallet and get balance: \(error)")
            return nil
        }
    }
    
    /// Get detailed balance breakdown (confirmed, pending, total)
    func getDetailedBalance() async -> (confirmed: UInt64, pending: UInt64, total: UInt64)? {
        print("💰 [BitcoinWalletService] ========== GET DETAILED BALANCE START ==========")
        
        guard let wallet else { 
            print("❌ [BitcoinWalletService] No wallet available for balance check!")
            print("   🔍 Wallet instance: nil")
            return nil 
        }
        print("✅ [BitcoinWalletService] Wallet is available")
        
        guard let esploraClient else { 
            print("❌ [BitcoinWalletService] No Esplora client available for balance check!")
            print("   🔍 EsploraClient instance: nil")
            return nil 
        }
        print("✅ [BitcoinWalletService] Esplora client is available")
        
        do {
            // Sync first to get latest state
            print("🔄 [BitcoinWalletService] Syncing wallet before balance check...")
            try await syncWallet()
            print("✅ [BitcoinWalletService] Wallet sync completed")
            
            let balance = wallet.balance()
            print("🔍 [BitcoinWalletService] Raw balance from wallet:")
            print("   ✅ Confirmed: \(balance.confirmed.toSat()) sats")
            print("   ⏳ Trusted pending: \(balance.trustedPending.toSat()) sats")
            print("   ❓ Untrusted pending: \(balance.untrustedPending.toSat()) sats")
            print("   📊 Total from wallet: \(balance.total.toSat()) sats")
            
            let confirmed = balance.confirmed.toSat()
            let pending = balance.trustedPending.toSat() + balance.untrustedPending.toSat()
            let total = balance.total.toSat()
            
            print("💰 [BitcoinWalletService] Processed balance details:")
            print("   ✅ Confirmed: \(confirmed) sats")
            print("   ⏳ Pending (total): \(pending) sats")  
            print("   📊 Total: \(total) sats")
            
            let result = (confirmed: confirmed, pending: pending, total: total)
            print("💰 [BitcoinWalletService] ========== GET DETAILED BALANCE END (SUCCESS) ==========")
            return result
        } catch {
            print("❌ [BitcoinWalletService] Failed to get detailed balance: \(error)")
            print("   🔍 Error type: \(type(of: error))")
            print("   🔍 Error description: \(error.localizedDescription)")
            if let bdkError = error as? EsploraError {
                print("   🔍 BDK Error: \(bdkError)")
            }
            print("💰 [BitcoinWalletService] ========== GET DETAILED BALANCE END (FAILED) ==========")
            return nil
        }
    }
    
    // MARK: - Transactions
    /// Get all transactions for this wallet
    func getTransactions() async -> [CanonicalTx]? {
        guard let wallet else {
            print("❌ [BitcoinWalletService] No wallet available for transaction query")
            return nil
        }
        
        guard let esploraClient else {
            print("❌ [BitcoinWalletService] No Esplora client available for transaction query")
            return nil
        }
        
        do {
            print("🔄 [BitcoinWalletService] Syncing wallet before fetching transactions...")
            
            // Sync wallet first to get latest transactions
            try await syncWallet()
            
            // Get all transactions
            let transactions = wallet.transactions()
            print("📋 [BitcoinWalletService] Found \(transactions.count) transactions")
            
            // Sort by confirmation time (newest first) using correct BDK API
            let sortedTransactions = transactions.sorted { (tx1, tx2) in
                return !tx1.chainPosition.isBefore(tx2.chainPosition)
            }
            
            // Log transaction details for debugging
            for (index, tx) in sortedTransactions.enumerated() {
                let txid = tx.transaction.computeTxid()
                
                // Check confirmation status based on ChainPosition
                let (isConfirmed, blockTime) = getTransactionInfo(chainPosition: tx.chainPosition)
                
                print("📄 [BitcoinWalletService] Transaction \(index + 1):")
                print("   🆔 TXID: \(txid)")
                print("   ✅ Confirmed: \(isConfirmed)")
                print("   ⏰ Block Time: \(blockTime)")
                
                // Get sent/received amounts
                let sentReceived = wallet.sentAndReceived(tx: tx.transaction)
                print("   📤 Sent: \(sentReceived.sent.toSat()) sats")
                print("   📥 Received: \(sentReceived.received.toSat()) sats")
            }
            
            return sortedTransactions
        } catch {
            print("❌ [BitcoinWalletService] Failed to get transactions: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Sync Methods
    /// Internal sync method using correct BDK API
    private func syncWallet() async throws {
        guard let wallet else { throw WalletError.noExistingWallet }
        guard let esploraClient else { throw WalletError.keychainAccessFailed }
        
        print("🔄 [BitcoinWalletService] Starting wallet sync...")
        print("   📍 Network: \(network)")
        print("   🌐 Esplora URL: https://blockstream.info/api")
        
        // Log current wallet state before sync
        let balanceBefore = wallet.balance()
        print("   💰 Balance before sync: \(balanceBefore.confirmed.toSat()) confirmed, \(balanceBefore.total.toSat()) total")
        
        // Create sync inspector for progress tracking
        let inspector = WalletSyncScriptInspector { inspected, total in
            // Simple progress tracking - could be enhanced with UI progress bar
            print("🔄 [BitcoinWalletService] Sync progress: \(inspected)/\(total)")
        }
        
        // Start sync with revealed SPKs (faster than full scan)
        print("🔍 [BitcoinWalletService] Starting sync with revealed SPKs...")
        let syncRequest = try wallet.startSyncWithRevealedSpks()
            .inspectSpks(inspector: inspector)
            .build()
        
        print("📡 [BitcoinWalletService] Calling esplora.sync()...")
        let update = try esploraClient.sync(
            request: syncRequest,
            parallelRequests: UInt64(5)
        )
        
        print("📦 [BitcoinWalletService] Applying update to wallet...")
        let _ = try wallet.applyUpdate(update: update)
        
        // Log wallet state after sync
        let balanceAfter = wallet.balance()
        print("✅ [BitcoinWalletService] Sync completed:")
        print("   💰 Balance after sync: \(balanceAfter.confirmed.toSat()) confirmed, \(balanceAfter.total.toSat()) total")
        print("   📋 Transactions: \(wallet.transactions().count)")
        
        // Persist changes
        persist()
    }
    
    /// Helper method to extract transaction info from ChainPosition
    private func getTransactionInfo(chainPosition: ChainPosition) -> (isConfirmed: Bool, blockTime: UInt64) {
        switch chainPosition {
        case .confirmed(let blockTime, _):
            return (true, UInt64(blockTime.blockId.height))
        case .unconfirmed(let timestamp):
            return (false, timestamp ?? 0)
        }
    }
    
    /// Load existing wallet with single Face ID prompt by consolidating keychain access
    private func loadExistingWalletWithSingleAuth() throws {
        guard let keychain = keychain else {
            print("❌ [BitcoinWalletService] Keychain not initialized")
            throw WalletError.keychainAccessFailed
        }
        
        print("🔍 [BitcoinWalletService] Loading existing wallet (mnemonic only)...")
        
        // Get ONLY the mnemonic from keychain
        print("🔐 [BitcoinWalletService] Requesting mnemonic from keychain...")
        
        var mnemonic: String?
        var cachedAddress: String?
        
        do {
            // With enhanced security, each keychain access now requires biometrics.
            // This might result in two separate prompts for the user.
            print("🔐 [BitcoinWalletService] Requesting mnemonic from keychain (biometrics required)...")
            mnemonic = try keychain.get(Keys.mnemonic)
            
            print("🔐 [BitcoinWalletService] Requesting cached address from keychain (biometrics required)...")
            cachedAddress = try keychain.get(Keys.currentAddress)
            
            print("✅ [BitcoinWalletService] Retrieved data from keychain")
            print("   📝 Mnemonic: \(mnemonic != nil ? "Found (\(mnemonic!.count) chars)" : "Not found")")
            print("   📝 Cached address: \(cachedAddress ?? "Not found")")
            
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to get mnemonic from keychain: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            throw WalletError.noExistingWallet
        }
        
        // Validate we have the mnemonic
        guard let mnemonicStr = mnemonic else {
            print("❌ [BitcoinWalletService] No mnemonic found in keychain")
            throw WalletError.noExistingWallet
        }

        // Now that we have the local seed, verify our encrypted cloud backup.
        // This runs in the background.
        Task {
            await self.verifyCloudBackup(against: mnemonicStr)
        }
        
        // Always regenerate descriptors from mnemonic
        print("🔧 [BitcoinWalletService] Regenerating descriptors from mnemonic...")
        let mnemonicObj = try Mnemonic.fromString(mnemonic: mnemonicStr)
        let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonicObj, password: nil)
        let descriptor = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network).toStringWithSecret()
        let changeDescriptor = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network).toStringWithSecret()
        print("✅ [BitcoinWalletService] Descriptors regenerated successfully")
        
        // Clean up any old descriptor entries from previous versions
        print("🧹 [BitcoinWalletService] Cleaning up old descriptor entries...")
        try? keychain.remove("nuri.wallet.descriptor")
        try? keychain.remove("nuri.wallet.changeDescriptor")
        
        // Load wallet with regenerated descriptors
        print("🔧 [BitcoinWalletService] Loading wallet with regenerated descriptors...")
        try loadWallet(descriptor: descriptor, changeDescriptor: changeDescriptor)
        print("✅ [BitcoinWalletService] Wallet loaded successfully")
        
        // Restore cached address if available
        if let cachedAddress = cachedAddress {
            currentBitcoinAddress = cachedAddress
            print("🔑 [BitcoinWalletService] Cached address restored: \(cachedAddress)")
        } else {
            // Generate first address if no cached address exists
            if let wallet = self.wallet {
                let addressInfo = wallet.revealNextAddress(keychain: .external)
                currentBitcoinAddress = addressInfo.address.description
                // Save the new address to keychain (this won't trigger Face ID since we just authenticated)
                do {
                    try keychain.set(currentBitcoinAddress!, key: Keys.currentAddress)
                    print("🔑 [BitcoinWalletService] Generated and cached new address: \(currentBitcoinAddress!)")
                } catch {
                    print("⚠️ [BitcoinWalletService] Failed to cache new address: \(error)")
                }
                persist()
            }
        }
        
        print("✅ [BitcoinWalletService] Wallet loaded with single authentication for user: \(currentUserID ?? "unknown")")
    }

    // MARK: - Encrypted Cloud Backup
    
    /// FOR DEBUGGING: returns the decrypted seed phrase from the iCloud backup.
    func testDecryptCloudBackup() async -> String {
        print("🧪 [BitcoinWalletService] Starting DEBUG decryption test...")
        guard let backupKeychain = backupKeychain else {
            let message = "   ❌ Backup keychain not available."
            print(message)
            return message
        }

        do {
            guard let encryptedBackup = try backupKeychain.get(Keys.encryptedMnemonicBackup) else {
                let message = "   ℹ️ No encrypted backup found in iCloud Keychain."
                print(message)
                return message
            }
            
            print("   ✅ Found encrypted backup data in iCloud Keychain.")
            
            // This call will trigger biometrics to get the local encryption key.
            let decryptedSeed = try SeedBackupService.shared.decrypt(backupString: encryptedBackup)
            
            let message = "✅ SUCCESS!\n\n\(decryptedSeed)"
            print("   \(message)")
            return message
            
        } catch {
            let message = "❌ FAILED to decrypt iCloud backup: \(error.localizedDescription)"
            print("   \(message)")
            return message
        }
    }
    
    /// Creates an encrypted backup of the seed phrase and stores it in the iCloud Keychain.
    private func createEncryptedBackup(for seedPhrase: String) async {
        print("☁️ [BitcoinWalletService] Preparing to create encrypted iCloud backup...")
        guard let backupKeychain = backupKeychain else {
            print("   ❌ Backup keychain not available for creating backup.")
            return
        }
        do {
            // The SeedBackupService handles generating a device-local key and encrypting the data.
            // This call will trigger biometrics to get the encryption key.
            let encryptedSeed = try SeedBackupService.shared.encrypt(seedPhrase: seedPhrase)
            print("   ✅ Seed successfully encrypted.")
            
            // Store the resulting encrypted string in our separate, iCloud-synced keychain.
            try backupKeychain.set(encryptedSeed, key: Keys.encryptedMnemonicBackup)
            print("   ✅ Encrypted backup stored in iCloud Keychain.")
            print("      🔑 Item key: \(Keys.encryptedMnemonicBackup)")
        } catch {
            print("   ❌ Failed to create encrypted iCloud backup: \(error.localizedDescription)")
        }
    }
    
    /// Verifies that an encrypted backup exists in iCloud Keychain and that it can be decrypted.
    private func verifyCloudBackup(against localSeed: String) async {
        print("🔎☁️ [BitcoinWalletService] Verifying encrypted iCloud backup...")
        guard let backupKeychain = backupKeychain else {
            print("   ❌ Backup keychain not available for verification.")
            return
        }

        do {
            // 1. Try to fetch the encrypted backup from iCloud Keychain.
            guard let encryptedBackup = try backupKeychain.get(Keys.encryptedMnemonicBackup) else {
                print("   ℹ️ No encrypted backup found in iCloud Keychain.")
                print("   🤔 This is normal for a wallet created before this feature was added.")
                // If no backup exists, create one now for this existing wallet.
                print("   ☁️ Creating encrypted backup now for existing wallet...")
                await createEncryptedBackup(for: localSeed)
                return
            }
            
            print("   ✅ Found encrypted backup data in iCloud Keychain (\(encryptedBackup.count) chars).")
            
            // 2. Try to decrypt it. This requires biometrics to access the local encryption key.
            let decryptedSeed = try SeedBackupService.shared.decrypt(backupString: encryptedBackup)
            print("   ✅ Backup decrypted successfully.")
            
            // 3. Compare the decrypted backup with the seed loaded from the local device.
            if decryptedSeed == localSeed {
                print("   ✅ SUCCESS! Decrypted iCloud backup matches the local wallet seed.")
            } else {
                print("   🚨 CRITICAL ERROR: Decrypted iCloud backup DOES NOT MATCH the local wallet seed!")
            }
        } catch {
            print("   ❌ Failed to verify or decrypt iCloud backup: \(error.localizedDescription)")
            // This can happen if the user cancels the biometric prompt, which is not a critical error.
        }
    }
}

// MARK: - Sync Script Inspector
actor WalletSyncScriptInspector: @preconcurrency SyncScriptInspector {
    private let updateProgress: @Sendable (UInt64, UInt64) -> Void
    private var inspectedCount: UInt64 = 0
    private var totalCount: UInt64 = 0

    init(updateProgress: @escaping @Sendable (UInt64, UInt64) -> Void) {
        self.updateProgress = updateProgress
    }

    func inspect(script: Script, total: UInt64) {
        totalCount = total
        inspectedCount += 1
        updateProgress(inspectedCount, totalCount)
    }
}

// MARK: - ChainPosition Extension
extension ChainPosition {
    func isBefore(_ other: ChainPosition) -> Bool {
        switch (self, other) {
        case (.unconfirmed, .confirmed):
            return true
        case (.confirmed, .unconfirmed):
            return false
        case (.unconfirmed(let timestamp1), .unconfirmed(let timestamp2)):
            return (timestamp1 ?? 0) < (timestamp2 ?? 0)
        case (
            .confirmed(let blockTime1, let transitively1),
            .confirmed(let blockTime2, let transitively2)
        ):
            return blockTime1.blockId.height != blockTime2.blockId.height
                ? blockTime1.blockId.height > blockTime2.blockId.height
                : (transitively1 != nil) && (transitively2 == nil)
        }
    }
}
