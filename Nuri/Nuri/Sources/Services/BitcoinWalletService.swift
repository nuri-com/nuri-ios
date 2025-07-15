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
    private var addressKeychain: Keychain?
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
        
        // Only generate new address if wallet is initialized
        guard let wallet else { 
            print("❌ [BitcoinWalletService] No wallet available to generate address")
            return nil 
        }
        
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
        // First check if wallet is loaded in memory
        if wallet != nil {
            print("🔍 [BitcoinWalletService] hasWallet() - wallet loaded in memory: true")
            return true
        }
        
        // Check if we have a cached address (indicates wallet exists)
        if let _ = loadAddressFromKeychain() {
            print("🔍 [BitcoinWalletService] hasWallet() - found cached address: true")
            return true
        }
        
        print("🔍 [BitcoinWalletService] hasWallet() - no wallet found: false")
        return false
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
        Task {
            await createAndStoreWallet()
        }
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
        
        // DISABLED: Force cleanup - only use manual cleanup button for testing
        // print("🧹 [BitcoinWalletService] FORCE CLEARING ALL KEYCHAIN SERVICES...")
        // forceCleanAllKeychainServices()
        
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
        
        // Try to load address without Face ID first
        if let cachedAddress = loadAddressFromKeychain() {
            currentBitcoinAddress = cachedAddress
            print("✅ [BitcoinWalletService] Found cached address without Face ID: \(cachedAddress)")
        }
        
        // Initialize wallet in background
        Task {
            initialiseWallet()
        }
    }
    
    /// FORCE clear ALL keychain services (for testing)
    func forceCleanAllKeychainServices() {
        let keychainServices = [
            "com.nuri.bitcoin-wallet",
            "com.nuri.bitcoin-wallet.backup", 
            "com.nuri.bitcoin-wallet.addresses",
            "com.nuri.bitcoin-wallet.default-user",
            "com.nuri.seed-backup-key",
            "com.nuri.seed-backup-key-simple",
            "com.nuri.iCloudBackup"
        ]
        
        for service in keychainServices {
            do {
                let keychain = Keychain(service: service)
                try keychain.removeAll()
                print("   ✅ Cleared keychain service: \(service)")
            } catch {
                print("   ⚠️ Failed to clear \(service): \(error)")
            }
        }
        
        // Also clear access group
        do {
            let accessGroupKeychain = Keychain(service: "com.nuri.mobile-ios", accessGroup: "MH2SRQ3N27.com.nuri.mobile-ios")
            try accessGroupKeychain.removeAll()
            print("   ✅ Cleared access group keychain")
        } catch {
            print("   ⚠️ Failed to clear access group: \(error)")
        }
        
        // Also clear Documents directory
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let walletDir = docs.appendingPathComponent("wallet_data")
            if FileManager.default.fileExists(atPath: walletDir.path) {
                try FileManager.default.removeItem(at: walletDir)
                print("   ✅ Cleared wallet_data directory")
            } else {
                print("   ℹ️ wallet_data directory not found")
            }
        } catch {
            print("   ⚠️ Failed to clear wallet_data directory: \(error)")
        }
        
        print("🧹 [BitcoinWalletService] Force cleanup completed")
    }
    
    /// Try to restore wallet from iCloud backup
    private func tryRestoreFromiCloudBackup() async -> String? {
        print("☁️ [BitcoinWalletService] Checking for iCloud backup...")
        
        guard let backupKeychain = backupKeychain else {
            print("   ❌ Backup keychain not available")
            return nil
        }
        
        do {
            // Check if encrypted backup exists in iCloud
            guard let encryptedBackup = try backupKeychain.get(Keys.encryptedMnemonicBackup) else {
                print("   ℹ️ No encrypted backup found in iCloud keychain")
                return nil
            }
            
            print("   ✅ Found encrypted backup in iCloud keychain")
            print("   🔓 Attempting to decrypt backup (may require Face ID)...")
            
            // Decrypt the backup using simple encryption
            let decryptedSeed = try SimpleEncryptionService.shared.decrypt(encryptedBase64: encryptedBackup)
            
            print("   ✅ Successfully decrypted iCloud backup")
            return decryptedSeed
            
        } catch {
            print("   ❌ Failed to restore from iCloud backup: \(error)")
            return nil
        }
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
        
        // This keychain is for encrypted backups - MUST sync to iCloud for backup/restore
        backupKeychain = Keychain(service: "com.nuri.bitcoin-wallet.backup")
            .synchronizable(true) // iCloud sync ENABLED for encrypted backup recovery
            .accessibility(.afterFirstUnlock) // No biometric check on the encrypted data itself.
        
        // Address keychain - no biometric protection needed for public addresses
        addressKeychain = Keychain(service: "com.nuri.bitcoin-wallet.addresses")
            .synchronizable(false) // Addresses are device-specific
            .accessibility(.afterFirstUnlock) // No biometric check for addresses

        print("🔑 [BitcoinWalletService] Keychain configured:")
        print("   (Local Seed) 🌩️ iCloud sync: DISABLED for security")
        print("   (Local Seed) 🔓 Accessibility: .whenUnlockedThisDeviceOnly")
        print("   (Local Seed) 📱 Authentication: .userPresence")
        print("   (Backup)     ☁️ iCloud sync: ENABLED for encrypted backup recovery")
        print("   (Address)    📍 No biometric auth required for public addresses")
    }

    // MARK: - Private helpers
    private func initialiseWallet() {
        print("🚀 [BitcoinWalletService] initialiseWallet() called")
        print("📊 [BitcoinWalletService] Current state:")
        print("   - User ID: \(currentUserID ?? "none")")
        print("   - Wallet exists: \(wallet != nil)")
        print("   - Keychain initialized: \(keychain != nil)")
        print("   - Backup keychain initialized: \(backupKeychain != nil)")
        print("   - Address keychain initialized: \(addressKeychain != nil)")
        
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
            Task {
                await createAndStoreWallet()
            }
        } catch WalletError.keychainAccessFailed {
            print("❌ [BitcoinWalletService] Keychain access failed - may need biometric auth")
            // Don't create new wallet immediately, wait for explicit user action
        } catch {
            print("⚠️ [BitcoinWalletService] Failed to load existing wallet: \(error)")
            // Only create new wallet if we're certain the existing one is corrupted
            Task {
                await createAndStoreWallet()
            }
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
            
            // If no mnemonic in keychain, clean up any leftover database files for security
            print("🗑️ [BitcoinWalletService] No mnemonic found - cleaning up any leftover wallet data for security")
            cleanupAllWalletData()
            
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
    
    /// DEBUG: Comprehensive storage diagnostics 
    func comprehensiveStorageDiagnostic() -> String {
        print("🔍 [BitcoinWalletService] COMPREHENSIVE STORAGE DIAGNOSTIC...")
        var results: [String] = []
        
        let header = "🔍 COMPREHENSIVE STORAGE DIAGNOSTIC"
        let separator = "====================================="
        results.append(header)
        results.append(separator)
        print(header)
        print(separator)
        
        // 1. Check ALL keychain services
        let keychainHeader = "\n🔑 KEYCHAIN SERVICES:"
        results.append(keychainHeader)
        print(keychainHeader)
        
        let keychainServices = [
            "com.nuri.bitcoin-wallet",
            "com.nuri.bitcoin-wallet.backup", 
            "com.nuri.bitcoin-wallet.addresses",
            "com.nuri.seed-backup-key",
            "com.nuri.seed-backup-key-simple",
            "com.nuri.iCloudBackup",
            currentUserID.map { "com.nuri.bitcoin-wallet.\($0)" } ?? "USER_ID_SERVICE"
        ]
        
        for service in keychainServices {
            let keychain = Keychain(service: service)
            let mnemonicExists = (try? keychain.contains(Keys.mnemonic)) ?? false
            let backupExists = (try? keychain.contains(Keys.encryptedMnemonicBackup)) ?? false
            let addressExists = (try? keychain.contains(Keys.currentAddress)) ?? false
            
            let serviceHeader = "   📦 \(service):"
            let mnemonicStatus = "      🌱 Mnemonic: \(mnemonicExists ? "❌ EXISTS" : "✅ Clean")"
            let backupStatus = "      💾 Backup: \(backupExists ? "❌ EXISTS" : "✅ Clean")"
            let addressStatus = "      📍 Address: \(addressExists ? "❌ EXISTS" : "✅ Clean")"
            
            results.append(serviceHeader)
            results.append(mnemonicStatus)
            results.append(backupStatus)
            results.append(addressStatus)
            
            print(serviceHeader)
            print(mnemonicStatus)
            print(backupStatus)
            print(addressStatus)
        }
        
        // 2. Check keychain access group
        let accessGroupHeader = "\n🏪 KEYCHAIN ACCESS GROUP:"
        results.append(accessGroupHeader)
        print(accessGroupHeader)
        
        let accessGroupKeychain = Keychain(service: "com.nuri.mobile-ios", accessGroup: "MH2SRQ3N27.com.nuri.mobile-ios")
        let groupMnemonicExists = (try? accessGroupKeychain.contains("mnemonic")) ?? false
        let groupBackupExists = (try? accessGroupKeychain.contains("backup")) ?? false
        
        let accessGroupInfo = "   🔒 Access Group: MH2SRQ3N27.com.nuri.mobile-ios"
        let groupMnemonicStatus = "   🌱 Mnemonic in group: \(groupMnemonicExists ? "❌ EXISTS" : "✅ Clean")"
        let groupBackupStatus = "   💾 Backup in group: \(groupBackupExists ? "❌ EXISTS" : "✅ Clean")"
        
        results.append(accessGroupInfo)
        results.append(groupMnemonicStatus)
        results.append(groupBackupStatus)
        
        print(accessGroupInfo)
        print(groupMnemonicStatus)
        print(groupBackupStatus)
        
        // 3. Test BDK randomness
        let randomnessHeader = "\n🎲 BDK RANDOMNESS TEST:"
        results.append(randomnessHeader)
        print(randomnessHeader)
        
        do {
            let mnemonic1 = Mnemonic(wordCount: .words12)
            let mnemonic2 = Mnemonic(wordCount: .words12) 
            let mnemonic3 = Mnemonic(wordCount: .words12)
            
            let mnemonic1Text = "   🎯 Mnemonic 1: \(mnemonic1.description.prefix(20))..."
            let mnemonic2Text = "   🎯 Mnemonic 2: \(mnemonic2.description.prefix(20))..."
            let mnemonic3Text = "   🎯 Mnemonic 3: \(mnemonic3.description.prefix(20))..."
            
            results.append(mnemonic1Text)
            results.append(mnemonic2Text)
            results.append(mnemonic3Text)
            
            print(mnemonic1Text)
            print(mnemonic2Text)
            print(mnemonic3Text)
            
            // Also log full mnemonics to Xcode console for debugging
            print("   🔍 FULL Mnemonic 1: \(mnemonic1.description)")
            print("   🔍 FULL Mnemonic 2: \(mnemonic2.description)")
            print("   🔍 FULL Mnemonic 3: \(mnemonic3.description)")
            
            let allDifferent = mnemonic1.description != mnemonic2.description && 
                             mnemonic2.description != mnemonic3.description &&
                             mnemonic1.description != mnemonic3.description
            
            let randomnessResult = "   🔍 All different: \(allDifferent ? "✅ RANDOM" : "❌ DETERMINISTIC!")"
            results.append(randomnessResult)
            print(randomnessResult)
            
            if !allDifferent {
                let warning1 = "   🚨 BDK IS GENERATING IDENTICAL MNEMONICS!"
                let warning2 = "   🚨 This explains the persistence issue!"
                results.append(warning1)
                results.append(warning2)
                print(warning1)
                print(warning2)
            }
        } catch {
            let errorMsg = "   ❌ Error testing BDK randomness: \(error)"
            results.append(errorMsg)
            print(errorMsg)
        }
        
        let finalResult = results.joined(separator: "\n")
        print("🔍 [BitcoinWalletService] DIAGNOSTIC COMPLETE - Results logged above")
        return finalResult
    }

    /// DEBUG: Test security cleanup without actually deleting files
    func testSecurityCleanup() -> String {
        print("🔍 [BitcoinWalletService] Testing security cleanup (DEBUG mode)...")
        var results: [String] = []
        
        do {
            // Check if wallet database exists
            let dbPath = try walletDBPath()
            let dbExists = FileManager.default.fileExists(atPath: dbPath)
            results.append("📄 Wallet DB exists: \(dbExists)")
            if dbExists {
                results.append("   📋 Path: \(dbPath)")
            }
            
            // Check if wallet_data directory exists
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let walletDir = docs.appendingPathComponent("wallet_data")
            let walletDirExists = FileManager.default.fileExists(atPath: walletDir.path)
            results.append("📁 Wallet directory exists: \(walletDirExists)")
            if walletDirExists {
                results.append("   📋 Path: \(walletDir.path)")
            }
            
            // Check keychain entries
            results.append("\n🔑 KEYCHAIN STATUS:")
            if let keychain = keychain {
                let hasSeeedPhrase = (try? keychain.get(Keys.mnemonic)) != nil
                results.append("   🌱 Has seed phrase: \(hasSeeedPhrase)")
            }
            
            if let addressKeychain = addressKeychain {
                let hasAddress = (try? addressKeychain.get(Keys.currentAddress)) != nil
                results.append("   📍 Has cached address: \(hasAddress)")
            }
            
            if let backupKeychain = backupKeychain {
                let hasBackup = (try? backupKeychain.get(Keys.encryptedMnemonicBackup)) != nil
                results.append("   💾 Has encrypted backup: \(hasBackup)")
            }
            
            results.append("\n✅ Security test completed - no files were modified")
            
        } catch {
            results.append("❌ Error during security test: \(error)")
        }
        
        let report = results.joined(separator: "\n")
        print("🔍 [BitcoinWalletService] Security test report:\n\(report)")
        return report
    }

    /// Completely removes all wallet data from the device for security purposes.
    /// This should be called when no mnemonic is found in keychain to prevent 
    /// any leftover data from persisting across app reinstalls.
    private func cleanupAllWalletData() {
        print("🗑️ [BitcoinWalletService] Starting complete wallet data cleanup for security...")
        
        do {
            // 1. Remove the wallet database file
            let dbPath = try walletDBPath()
            if FileManager.default.fileExists(atPath: dbPath) {
                try FileManager.default.removeItem(atPath: dbPath)
                print("   ✅ Removed wallet database: \(dbPath)")
            } else {
                print("   ℹ️ Wallet database not found (already clean)")
            }
            
            // 2. Remove the entire wallet_data directory if it exists
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let walletDir = docs.appendingPathComponent("wallet_data")
            if FileManager.default.fileExists(atPath: walletDir.path) {
                try FileManager.default.removeItem(at: walletDir)
                print("   ✅ Removed wallet_data directory: \(walletDir.path)")
            }
            
            // 3. Clear all cached addresses from address keychain
            if let addressKeychain = addressKeychain {
                try? addressKeychain.removeAll()
                print("   ✅ Cleared all cached addresses")
            }
            
            // 4. Clear all cached data from WalletStateManager
            Task { @MainActor in
                WalletStateManager.shared.clearAllCache()
                print("   ✅ Cleared all state manager cache")
            }
            
            // 5. Clear any backup data (though this should be encrypted and useless without the key)
            if let backupKeychain = backupKeychain {
                try? backupKeychain.removeAll()
                print("   ✅ Cleared backup keychain (encrypted data)")
            }
            
            print("✅ [BitcoinWalletService] Complete wallet data cleanup finished")
            print("🔒 [BitcoinWalletService] Device is now clean - no wallet data persists")
            
        } catch {
            print("❌ [BitcoinWalletService] Error during wallet cleanup: \(error)")
            print("⚠️ [BitcoinWalletService] Some data may still persist - manual cleanup may be needed")
        }
    }

    private func loadWallet(descriptor: String, changeDescriptor: String) throws {
        print("🔧 [BitcoinWalletService] loadWallet() called")
        print("   📝 Descriptor length: \(descriptor.count)")
        print("   📝 Change descriptor length: \(changeDescriptor.count)")
        
        let dbPath = try walletDBPath()
        print("   📋 Database path: \(dbPath)")
        
        // Parse descriptors first so they're available in catch block
        let desc: Descriptor
        let changeDesc: Descriptor
        
        do {
            desc = try Descriptor(descriptor: descriptor, network: network)
            print("   ✅ External descriptor parsed successfully")
            
            changeDesc = try Descriptor(descriptor: changeDescriptor, network: network)
            print("   ✅ Internal descriptor parsed successfully")
        } catch {
            print("   ❌ Failed to parse descriptors: \(error)")
            throw error
        }
        
        do {
            let conn = try Connection(path: dbPath)
            print("   ✅ Database connection established")
            
            self.wallet = try Wallet.load(descriptor: desc, changeDescriptor: changeDesc, connection: conn)
            self.connection = conn
            print("   ✅ Wallet loaded successfully from database")
        } catch {
            print("   ❌ Failed to load wallet: \(error)")
            
            // Check if it's a descriptor mismatch error or load failure
            if "\(error)".contains("data mismatch") || "\(error)".contains("InvalidChangeSet") || "\(error)".contains("CouldNotLoad") {
                print("   🔄 Wallet database has mismatched descriptors")
                print("   🗑️ Deleting old wallet database...")
                
                // Delete the old database file
                if FileManager.default.fileExists(atPath: dbPath) {
                    try? FileManager.default.removeItem(atPath: dbPath)
                    print("   ✅ Old database deleted")
                }
                
                // Try to create a new wallet with the same descriptors
                print("   🔄 Creating new wallet database...")
                do {
                    let newConn = try Connection(path: dbPath)
                    self.wallet = try Wallet(descriptor: desc, changeDescriptor: changeDesc, network: network, connection: newConn)
                    self.connection = newConn
                    print("   ✅ New wallet created successfully after database cleanup")
                    
                    // Clear cached data when database is recreated
                    Task { @MainActor in
                        WalletStateManager.shared.clearAllCache()
                    }
                    
                    // Clear cached address since we have a new wallet
                    currentBitcoinAddress = nil
                    if let addressKeychain = addressKeychain {
                        try? addressKeychain.remove(Keys.currentAddress)
                        print("   🗑️ Cleared cached address from keychain")
                    }
                } catch {
                    print("   ❌ Failed to create new wallet after cleanup: \(error)")
                    throw error
                }
            } else {
                // Re-throw other errors
                let nsError = error as NSError
                print("   📋 Error domain: \(nsError.domain)")
                print("   📋 Error code: \(nsError.code)")
                print("   📋 Error description: \(nsError.localizedDescription)")
                if let statusMessage = SecCopyErrorMessageString(OSStatus(nsError.code), nil) {
                    print("   📋 OSStatus description: \(statusMessage as String)")
                }
                throw error
            }
        }
    }

    private func createAndStoreWallet() async {
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
            print("ℹ️ [BitcoinWalletService] No existing seed found in local keychain")
            
            // Check for iCloud backup before creating new wallet
            if let recoveredSeed = await tryRestoreFromiCloudBackup() {
                print("✅ [BitcoinWalletService] Restored wallet from iCloud backup!")
                
                // Store recovered seed in local keychain
                do {
                    try keychain.set(recoveredSeed, key: Keys.mnemonic)
                    print("   ✅ Recovered seed stored in local keychain")
                    
                    // Continue with wallet creation using recovered seed
                    let mnemonicObj = try Mnemonic.fromString(mnemonic: recoveredSeed)
                    let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonicObj, password: nil)
                    let externalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network)
                    let internalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network)
                    
                    let dbPath = try walletDBPath()
                    let conn = try Connection(path: dbPath)
                    let wallet = try Wallet(descriptor: externalDesc, changeDescriptor: internalDesc, network: network, connection: conn)
                    self.wallet = wallet
                    self.connection = conn
                    
                    // Generate first address
                    let addressInfo = wallet.revealNextAddress(keychain: .external)
                    currentBitcoinAddress = addressInfo.address.description
                    saveAddressToKeychain(currentBitcoinAddress!)
                    persist()
                    
                    print("✅ [BitcoinWalletService] Wallet restored from iCloud backup")
                    return
                } catch {
                    print("❌ [BitcoinWalletService] Failed to restore from backup: \(error)")
                    // Fall through to create new wallet
                }
            } else {
                print("ℹ️ [BitcoinWalletService] No iCloud backup found, proceeding to create new wallet")
            }
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
            print("🔐 [BitcoinWalletService] Storing mnemonic to LOCAL keychain...")
            try keychain.set(mnemonic.description, key: Keys.mnemonic)
            print("   ✅ NEW mnemonic stored successfully to LOCAL keychain.")

            // Create encrypted backup immediately using simple encryption
            print("📋 [BitcoinWalletService] Creating encrypted backup immediately...")
            do {
                let encryptedBackup = try SimpleEncryptionService.shared.encrypt(data: mnemonic.description)
                print("   ✅ Seed encrypted successfully with simple encryption")
                
                // Store in iCloud backup keychain
                guard let backupKeychain = backupKeychain else {
                    print("   ❌ Backup keychain not available")
                    throw WalletError.keychainAccessFailed
                }
                try backupKeychain.set(encryptedBackup, key: Keys.encryptedMnemonicBackup)
                print("   ✅ Encrypted backup stored in iCloud keychain")
                
                // Verify it was stored
                if let stored = try? backupKeychain.get(Keys.encryptedMnemonicBackup) {
                    print("   ✅ Backup verified: \(stored.count) chars stored")
                } else {
                    print("   ⚠️ Could not verify backup was stored")
                }
            } catch {
                print("   ❌ Failed to create backup immediately: \(error)")
                print("   ℹ️ Backup can be created later from Security screen")
            }
            
            // Clean up any old descriptor entries from previous versions
            print("🧹 [BitcoinWalletService] Cleaning up any existing descriptor entries...")
            try? keychain.remove("nuri.wallet.descriptor")
            try? keychain.remove("nuri.wallet.changeDescriptor")
            print("   ✅ Descriptor entries cleaned up")
            
            // Mnemonic stored successfully (verification would require Face ID, skipping)
            
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
            
            // Clear any old cached data when new wallet is created
            Task { @MainActor in
                WalletStateManager.shared.clearAllCache()
            }
            
            // Also clear any old cached address
            if let addressKeychain = addressKeychain {
                // Simply remove all cached addresses when a new wallet is created
                try? addressKeychain.removeAll()
                print("🗑️ [BitcoinWalletService] Cleared all old cached addresses")
                
                // Store the new address
                if let newAddress = currentBitcoinAddress {
                    try? addressKeychain.set(newAddress, key: Keys.currentAddress)
                    print("💾 [BitcoinWalletService] Stored new address in cache")
                }
            }
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
        guard let addressKeychain = addressKeychain else {
            print("❌ [BitcoinWalletService] Cannot save address - address keychain not initialized")
            return
        }
        
        print("💾 [BitcoinWalletService] Saving address to keychain (NO Face ID required)...")
        do {
            try addressKeychain.set(address, key: Keys.currentAddress)
            print("✅ [BitcoinWalletService] Address saved to keychain WITHOUT biometric protection: \(address)")
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
        guard let addressKeychain = addressKeychain else {
            print("❌ [BitcoinWalletService] Cannot load address - address keychain not initialized")
            return nil
        }
        
        print("📖 [BitcoinWalletService] Loading address from keychain (NO Face ID required)...")
        do {
            let address = try addressKeychain.get(Keys.currentAddress)
            if let address = address {
                print("✅ [BitcoinWalletService] Address loaded from keychain WITHOUT biometric auth: \(address)")
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
            // Get mnemonic from secure keychain (requires Face ID)
            print("🔐 [BitcoinWalletService] Requesting mnemonic from keychain (biometrics required)...")
            mnemonic = try keychain.get(Keys.mnemonic)
            
            print("✅ [BitcoinWalletService] Retrieved mnemonic from keychain")
            print("   📝 Mnemonic: \(mnemonic != nil ? "Found (\(mnemonic!.count) chars)" : "Not found")")
            
            // Get cached address from address keychain (NO Face ID required)
            if let addressKeychain = addressKeychain {
                print("📖 [BitcoinWalletService] Loading cached address (no biometrics)...")
                cachedAddress = try? addressKeychain.get(Keys.currentAddress)
                print("   📝 Cached address: \(cachedAddress ?? "Not found")")
            }
            
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

        // Check if encrypted backup exists and create one if missing
        Task {
            await self.ensureBackupExists(for: mnemonicStr)
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
                saveAddressToKeychain(currentBitcoinAddress!)
                persist()
                print("🔑 [BitcoinWalletService] Generated and cached new address: \(currentBitcoinAddress!)")
            }
        }
        
        print("✅ [BitcoinWalletService] Wallet loaded with single authentication for user: \(currentUserID ?? "unknown")")
    }

    // MARK: - Encrypted Cloud Backup
    
    /// FOR DEBUGGING: returns the decrypted seed phrase from the iCloud backup.
    func testDecryptCloudBackup() async -> String {
        print("🧪 [BitcoinWalletService] Starting DEBUG decryption test...")
        
        // Ensure keychains are initialized
        if backupKeychain == nil {
            print("   ⚠️ Backup keychain not initialized. Initializing now...")
            setupKeychain(for: currentUserID ?? "default-user")
        }
        
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
            
            // Decrypt using simple encryption (no biometrics needed)
            let decryptedSeed = try SimpleEncryptionService.shared.decrypt(encryptedBase64: encryptedBackup)
            
            let message = "✅ SUCCESS!\n\n\(decryptedSeed)"
            print("   \(message)")
            return message
            
        } catch {
            let message = "❌ FAILED to decrypt iCloud backup: \(error.localizedDescription)"
            print("   \(message)")
            return message
        }
    }
    
    /// Manual backup creation for testing with DEEP debugging
    func createManualBackup() -> String {
        print("🔧 [BitcoinWalletService] DEEP DEBUG: Creating manual backup...")
        var debugInfo: [String] = []
        debugInfo.append("🔧 MANUAL BACKUP DEEP DEBUG:")
        debugInfo.append("=====================================")
        
        // 1. Check keychain initialization
        guard let keychain = keychain else {
            let msg = "❌ Local keychain not initialized"
            debugInfo.append(msg)
            print(msg)
            return debugInfo.joined(separator: "\n")
        }
        debugInfo.append("✅ Local keychain initialized")
        print("✅ Local keychain initialized")
        
        guard let backupKeychain = backupKeychain else {
            let msg = "❌ Backup keychain not initialized"
            debugInfo.append(msg)
            print(msg)
            return debugInfo.joined(separator: "\n")
        }
        debugInfo.append("✅ Backup keychain initialized")
        print("✅ Backup keychain initialized")
        
        // 2. Debug keychain configurations
        debugInfo.append("\n🔑 KEYCHAIN CONFIGURATION:")
        debugInfo.append("Local keychain service: com.nuri.bitcoin-wallet")
        debugInfo.append("Backup keychain service: com.nuri.bitcoin-wallet.backup")
        debugInfo.append("Backup keychain sync: true (iCloud)")
        print("🔑 Local keychain service: com.nuri.bitcoin-wallet")
        print("🔑 Backup keychain service: com.nuri.bitcoin-wallet.backup")
        print("🔑 Backup keychain sync: true (iCloud)")
        
        do {
            // 3. Get current seed phrase
            guard let seedPhrase = try keychain.get(Keys.mnemonic) else {
                let msg = "❌ No seed phrase found in local keychain"
                debugInfo.append("\n" + msg)
                print(msg)
                return debugInfo.joined(separator: "\n")
            }
            
            debugInfo.append("\n✅ Found seed phrase in local keychain")
            debugInfo.append("   📝 Seed length: \(seedPhrase.count) characters")
            debugInfo.append("   📝 Seed preview: \(seedPhrase.prefix(20))...")
            print("✅ Found seed phrase: \(seedPhrase.count) chars")
            
            // 4. Test simple encryption
            let currentPassword = SimpleEncryptionService.shared.getCurrentPassword()
            debugInfo.append("\n🔐 ENCRYPTION TEST:")
            debugInfo.append("   Password: \(currentPassword)")
            print("🔐 Using password: \(currentPassword)")
            
            let encryptedBackup = try SimpleEncryptionService.shared.encrypt(data: seedPhrase)
            debugInfo.append("   ✅ Encryption successful")
            debugInfo.append("   📝 Encrypted length: \(encryptedBackup.count) characters")
            debugInfo.append("   📝 Encrypted preview: \(encryptedBackup.prefix(50))...")
            print("✅ Encryption successful: \(encryptedBackup.count) chars")
            
            // 5. CRITICAL: Detailed keychain storage attempt
            debugInfo.append("\n💾 KEYCHAIN STORAGE ATTEMPT:")
            debugInfo.append("   Target service: com.nuri.bitcoin-wallet.backup")
            debugInfo.append("   Target key: \(Keys.encryptedMnemonicBackup)")
            debugInfo.append("   Data to store: \(encryptedBackup.count) chars")
            print("💾 Attempting keychain storage...")
            print("   Service: com.nuri.bitcoin-wallet.backup")
            print("   Key: \(Keys.encryptedMnemonicBackup)")
            print("   Data length: \(encryptedBackup.count)")
            
            // Try to store with detailed error handling
            do {
                try backupKeychain.set(encryptedBackup, key: Keys.encryptedMnemonicBackup)
                debugInfo.append("   ✅ backupKeychain.set() call completed without error")
                print("   ✅ backupKeychain.set() completed")
            } catch let error as NSError {
                let errorMsg = "   ❌ backupKeychain.set() failed: \(error)"
                debugInfo.append(errorMsg)
                debugInfo.append("   📋 Error domain: \(error.domain)")
                debugInfo.append("   📋 Error code: \(error.code)")
                debugInfo.append("   📋 Error description: \(error.localizedDescription)")
                print(errorMsg)
                print("   Error domain: \(error.domain)")
                print("   Error code: \(error.code)")
                return debugInfo.joined(separator: "\n")
            }
            
            // 6. CRITICAL: Immediate verification
            debugInfo.append("\n🔍 IMMEDIATE VERIFICATION:")
            print("🔍 Immediate verification...")
            
            do {
                if let storedData = try backupKeychain.get(Keys.encryptedMnemonicBackup) {
                    debugInfo.append("   ✅ Data found in keychain!")
                    debugInfo.append("   📝 Stored length: \(storedData.count) characters")
                    debugInfo.append("   📝 Stored preview: \(storedData.prefix(50))...")
                    debugInfo.append("   🎯 Matches original: \(storedData == encryptedBackup)")
                    print("   ✅ Data found: \(storedData.count) chars")
                    print("   🎯 Matches: \(storedData == encryptedBackup)")
                } else {
                    debugInfo.append("   ❌ Data NOT found in keychain immediately after storage!")
                    debugInfo.append("   🚨 This indicates keychain storage failed silently")
                    print("   ❌ Data NOT found immediately after storage!")
                }
            } catch let error as NSError {
                debugInfo.append("   ❌ Error reading back from keychain: \(error)")
                debugInfo.append("   📋 Read error domain: \(error.domain)")
                debugInfo.append("   📋 Read error code: \(error.code)")
                print("   ❌ Read error: \(error)")
            }
            
            // 7. Test decryption to verify password works
            debugInfo.append("\n🔓 DECRYPTION TEST:")
            do {
                let decrypted = try SimpleEncryptionService.shared.decrypt(encryptedBase64: encryptedBackup)
                let matches = decrypted == seedPhrase
                debugInfo.append("   ✅ Decryption successful")
                debugInfo.append("   🎯 Decrypted matches original: \(matches)")
                print("   ✅ Decryption test passed: \(matches)")
            } catch {
                debugInfo.append("   ❌ Decryption failed: \(error)")
                print("   ❌ Decryption test failed: \(error)")
            }
            
            return debugInfo.joined(separator: "\n")
            
        } catch let error as NSError {
            let errorMsg = "❌ Manual backup failed: \(error)"
            debugInfo.append("\n" + errorMsg)
            debugInfo.append("📋 Error domain: \(error.domain)")
            debugInfo.append("📋 Error code: \(error.code)")
            debugInfo.append("📋 Error description: \(error.localizedDescription)")
            print(errorMsg)
            return debugInfo.joined(separator: "\n")
        }
    }
    
    /// Creates an encrypted backup of the seed phrase and stores it in the iCloud Keychain.
    private func createEncryptedBackup(for seedPhrase: String) async {
        print("☁️ [BitcoinWalletService] Preparing to create encrypted iCloud backup...")
        print("   📝 Seed phrase length: \(seedPhrase.count) characters")
        print("   📝 First 20 chars: \(seedPhrase.prefix(20))...")
        
        guard let backupKeychain = backupKeychain else {
            print("   ❌ Backup keychain not available for creating backup.")
            return
        }
        do {
            // Use simple encryption with hardcoded password
            print("   🔐 Using simple encryption to encrypt seed...")
            let encryptedSeed = try SimpleEncryptionService.shared.encrypt(data: seedPhrase)
            print("   ✅ Seed successfully encrypted with simple encryption.")
            print("   📝 Encrypted data length: \(encryptedSeed.count) characters")
            
            // Store the resulting encrypted string in our separate, iCloud backup keychain.
            print("   💾 Storing encrypted backup to iCloud backup keychain...")
            try backupKeychain.set(encryptedSeed, key: Keys.encryptedMnemonicBackup)
            print("   ✅ Encrypted backup stored in iCloud backup keychain.")
            print("      🔑 Item key: \(Keys.encryptedMnemonicBackup)")
            print("      📍 Service: com.nuri.bitcoin-wallet.backup")
            print("      ☁️ Sync enabled: true (for backup/restore)")
            
            // Verify it was stored
            if let stored = try? backupKeychain.get(Keys.encryptedMnemonicBackup) {
                print("   ✅ Verified: Backup successfully stored (\(stored.count) chars)")
            } else {
                print("   ⚠️ Warning: Could not verify backup was stored")
            }
        } catch {
            print("   ❌ Failed to create encrypted iCloud backup: \(error)")
            print("   📝 Error type: \(type(of: error))")
            print("   📝 Error details: \(error.localizedDescription)")
            
            // Check if it's a user cancellation error
            if let backupError = error as? SeedBackupService.BackupError,
               case .keychainError(let nsError) = backupError,
               nsError.code == -128 { // errSecUserCancel
                print("   ℹ️ User cancelled Face ID for backup creation - this is okay")
                print("   ℹ️ Backup can be created later from Security screen")
            } else if let nsError = error as? NSError, nsError.code == -128 { // errSecUserCancel
                print("   ℹ️ User cancelled Face ID for backup creation - this is okay") 
                print("   ℹ️ Backup can be created later from Security screen")
            } else {
                print("   ⚠️ Backup creation failed for technical reasons")
                print("   ⚠️ This may be due to keychain access issues")
            }
        }
    }
    
    /// Ensures an encrypted backup exists in iCloud Keychain, creating one if missing.
    private func ensureBackupExists(for seedPhrase: String) async {
        print("🔎☁️ [BitcoinWalletService] Checking if encrypted iCloud backup exists...")
        guard let backupKeychain = backupKeychain else {
            print("   ❌ Backup keychain not available for check.")
            return
        }
        
        do {
            if let _ = try backupKeychain.get(Keys.encryptedMnemonicBackup) {
                print("   ✅ Encrypted backup found in iCloud Keychain.")
                return
            }
        } catch {
            print("   ⚠️ Could not check backup existence: \(error)")
        }
        
        // No backup found, create one now
        print("   ℹ️ No encrypted backup found in iCloud Keychain.")
        print("   🔨 Creating encrypted backup for existing wallet...")
        await createEncryptedBackup(for: seedPhrase)
    }
    
    /// Checks if an encrypted backup exists in iCloud Keychain (without verification).
    private func checkBackupExists() async {
        print("🔎☁️ [BitcoinWalletService] Checking if encrypted iCloud backup exists...")
        guard let backupKeychain = backupKeychain else {
            print("   ❌ Backup keychain not available for check.")
            return
        }
        
        do {
            if let _ = try backupKeychain.get(Keys.encryptedMnemonicBackup) {
                print("   ✅ Encrypted backup found in iCloud Keychain.")
            } else {
                print("   ℹ️ No encrypted backup found in iCloud Keychain.")
                print("   🤔 This is normal for a wallet created before this feature was added.")
                print("   ☁️ Backup can be created from Security screen.")
            }
        } catch {
            print("   ⚠️ Could not check backup existence: \(error)")
        }
    }
    
    /// Import and overwrite the current seed phrase with a new one (for testing)
    /// WARNING: This will permanently replace the existing wallet and all associated data
    func importAndOverwriteSeed(newSeedPhrase: String) async -> String {
        print("⚠️ [BitcoinWalletService] CRITICAL: Import and overwrite seed requested")
        print("⚠️ [BitcoinWalletService] New seed phrase: \(newSeedPhrase.prefix(20))...")
        
        var results: [String] = []
        results.append("🔄 IMPORT AND OVERWRITE SEED PHRASE:")
        results.append("=====================================")
        
        // Validate the seed phrase format
        do {
            let _ = try Mnemonic.fromString(mnemonic: newSeedPhrase)
            results.append("✅ Seed phrase validation: VALID")
            print("✅ [BitcoinWalletService] Seed phrase validation passed")
        } catch {
            let errorMsg = "❌ Invalid seed phrase format: \(error.localizedDescription)"
            results.append(errorMsg)
            print("❌ [BitcoinWalletService] \(errorMsg)")
            return results.joined(separator: "\n")
        }
        
        // Step 1: Clear ALL existing wallet data
        results.append("\n🗑️ STEP 1: Clearing existing wallet data...")
        print("🗑️ [BitcoinWalletService] Clearing all existing wallet data...")
        
        // Clear in-memory wallet
        self.wallet = nil
        self.connection = nil
        self.currentBitcoinAddress = nil
        
        // Force clean all keychain services
        forceCleanAllKeychainServices()
        results.append("   ✅ All keychain services cleared")
        
        // Clear state manager cache
        await WalletStateManager.shared.clearAllCache()
        results.append("   ✅ State manager cache cleared")
        
        // Step 2: Reinitialize keychain services
        results.append("\n🔑 STEP 2: Reinitializing keychain services...")
        print("🔑 [BitcoinWalletService] Reinitializing keychain services...")
        
        // Use current user ID or default
        let userID = currentUserID ?? "default-user"
        setupKeychain(for: userID)
        results.append("   ✅ Keychain services reinitialized")
        
        // Step 3: Store the new seed phrase
        results.append("\n💾 STEP 3: Storing new seed phrase...")
        print("💾 [BitcoinWalletService] Storing new seed phrase...")
        
        guard let keychain = keychain else {
            let errorMsg = "❌ Keychain not available for seed storage"
            results.append(errorMsg)
            return results.joined(separator: "\n")
        }
        
        do {
            // Store new seed in local keychain
            try keychain.set(newSeedPhrase, key: Keys.mnemonic)
            results.append("   ✅ New seed stored in local keychain")
            print("✅ [BitcoinWalletService] New seed stored in local keychain")
            
            // Create encrypted backup immediately
            let encryptedBackup = try SimpleEncryptionService.shared.encrypt(data: newSeedPhrase)
            
            if let backupKeychain = backupKeychain {
                try backupKeychain.set(encryptedBackup, key: Keys.encryptedMnemonicBackup)
                results.append("   ✅ Encrypted backup created in iCloud keychain")
                print("✅ [BitcoinWalletService] Encrypted backup created")
            } else {
                results.append("   ⚠️ Backup keychain not available - backup skipped")
                print("⚠️ [BitcoinWalletService] Backup keychain not available")
            }
            
        } catch {
            let errorMsg = "❌ Failed to store new seed: \(error.localizedDescription)"
            results.append(errorMsg)
            print("❌ [BitcoinWalletService] \(errorMsg)")
            return results.joined(separator: "\n")
        }
        
        // Step 4: Create new wallet from imported seed
        results.append("\n🔧 STEP 4: Creating wallet from imported seed...")
        print("🔧 [BitcoinWalletService] Creating wallet from imported seed...")
        
        do {
            // Parse the mnemonic and create descriptors
            let mnemonicObj = try Mnemonic.fromString(mnemonic: newSeedPhrase)
            let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonicObj, password: nil)
            let externalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network)
            let internalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network)
            
            // Create wallet database
            let dbPath = try walletDBPath()
            let conn = try Connection(path: dbPath)
            let newWallet = try Wallet(descriptor: externalDesc, changeDescriptor: internalDesc, network: network, connection: conn)
            
            self.wallet = newWallet
            self.connection = conn
            
            // Generate and cache first address
            let addressInfo = newWallet.revealNextAddress(keychain: .external)
            currentBitcoinAddress = addressInfo.address.description
            saveAddressToKeychain(currentBitcoinAddress!)
            persist()
            
            results.append("   ✅ New wallet created successfully")
            results.append("   📍 First address: \(currentBitcoinAddress!)")
            
            print("✅ [BitcoinWalletService] New wallet created successfully")
            print("📍 [BitcoinWalletService] First address: \(currentBitcoinAddress!)")
            
        } catch {
            let errorMsg = "❌ Failed to create wallet from imported seed: \(error.localizedDescription)"
            results.append(errorMsg)
            print("❌ [BitcoinWalletService] \(errorMsg)")
            return results.joined(separator: "\n")
        }
        
        results.append("\n✅ IMPORT COMPLETED SUCCESSFULLY!")
        results.append("🔄 Wallet is now using the imported seed phrase")
        results.append("⚠️ Previous wallet data has been permanently overwritten")
        
        // Force refresh all UI components
        results.append("\n🔄 STEP 5: Forcing complete UI refresh...")
        print("🔄 [BitcoinWalletService] Forcing complete UI refresh...")
        
        await forceCompleteWalletRefresh()
        results.append("   ✅ UI components refreshed")
        
        print("✅ [BitcoinWalletService] Import and overwrite completed successfully")
        
        return results.joined(separator: "\n")
    }
    
    /// Force wallet to use iCloud backup instead of local keychain (for testing/recovery)
    func forceRestoreFromiCloudBackup() async -> String {
        print("☁️ [BitcoinWalletService] FORCE restore from iCloud backup requested")
        
        var results: [String] = []
        results.append("☁️ FORCE RESTORE FROM ICLOUD BACKUP:")
        results.append("=====================================")
        
        // Step 1: Clear all local data first
        results.append("\n🗑️ STEP 1: Clearing all local wallet data...")
        print("🗑️ [BitcoinWalletService] Clearing all local data...")
        
        self.wallet = nil
        self.connection = nil
        self.currentBitcoinAddress = nil
        forceCleanAllKeychainServices()
        await WalletStateManager.shared.clearAllCache()
        results.append("   ✅ All local data cleared")
        
        // Step 2: Reinitialize keychain
        results.append("\n🔑 STEP 2: Reinitializing keychain services...")
        let userID = currentUserID ?? "default-user"
        setupKeychain(for: userID)
        results.append("   ✅ Keychain services reinitialized")
        
        // Step 3: Try to restore from iCloud
        results.append("\n☁️ STEP 3: Restoring from iCloud backup...")
        if let recoveredSeed = await tryRestoreFromiCloudBackup() {
            results.append("   ✅ Found iCloud backup")
            results.append("   🔓 Successfully decrypted backup")
            
            // Store in local keychain
            guard let keychain = keychain else {
                results.append("   ❌ Keychain not available")
                return results.joined(separator: "\n")
            }
            
            do {
                try keychain.set(recoveredSeed, key: Keys.mnemonic)
                results.append("   ✅ Restored seed stored in local keychain")
                
                // Create wallet from restored seed
                let mnemonicObj = try Mnemonic.fromString(mnemonic: recoveredSeed)
                let secretKey = DescriptorSecretKey(network: network, mnemonic: mnemonicObj, password: nil)
                let externalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .external, network: network)
                let internalDesc = Descriptor.newBip86(secretKey: secretKey, keychain: .internal, network: network)
                
                let dbPath = try walletDBPath()
                let conn = try Connection(path: dbPath)
                let newWallet = try Wallet(descriptor: externalDesc, changeDescriptor: internalDesc, network: network, connection: conn)
                
                self.wallet = newWallet
                self.connection = conn
                
                // Generate first address
                let addressInfo = newWallet.revealNextAddress(keychain: .external)
                currentBitcoinAddress = addressInfo.address.description
                saveAddressToKeychain(currentBitcoinAddress!)
                persist()
                
                results.append("   ✅ Wallet created from iCloud backup")
                results.append("   📍 First address: \(currentBitcoinAddress!)")
                
                // Force UI refresh
                await forceCompleteWalletRefresh()
                results.append("   ✅ UI refreshed")
                
                results.append("\n✅ ICLOUD RESTORE COMPLETED SUCCESSFULLY!")
                
            } catch {
                results.append("   ❌ Failed to create wallet from backup: \(error.localizedDescription)")
            }
        } else {
            results.append("   ❌ No iCloud backup found or decryption failed")
        }
        
        return results.joined(separator: "\n")
    }
    
    /// Force complete refresh of wallet state and UI components
    func forceCompleteWalletRefresh() async {
        print("🔄 [BitcoinWalletService] Force complete wallet refresh")
        
        // Clear all cached state
        await WalletStateManager.shared.clearAllCache()
        
        // Force refresh balance, transactions, and fee rates
        await WalletStateManager.shared.refreshAll()
        
        print("✅ [BitcoinWalletService] Complete wallet refresh finished")
    }
    
    /// Add force refresh button functionality for Security screen
    func forceRefreshEverything() async -> String {
        print("🔄 [BitcoinWalletService] Force refresh everything requested")
        
        var results: [String] = []
        results.append("🔄 FORCE REFRESH EVERYTHING:")
        results.append("==============================")
        
        // Clear all cached data
        results.append("\n🗑️ Clearing all cached data...")
        await WalletStateManager.shared.clearAllCache()
        results.append("   ✅ State manager cache cleared")
        
        // Clear address cache
        if let addressKeychain = addressKeychain {
            try? addressKeychain.removeAll()
            results.append("   ✅ Address cache cleared")
        }
        
        // Force wallet sync
        results.append("\n🔄 Force syncing wallet...")
        if let balance = await syncAndGetBalance() {
            results.append("   ✅ Balance synced: \(balance) sats")
        } else {
            results.append("   ⚠️ Balance sync failed")
        }
        
        // Force transaction sync
        if let transactions = await getTransactions() {
            results.append("   ✅ Transactions synced: \(transactions.count) found")
        } else {
            results.append("   ⚠️ Transaction sync failed")
        }
        
        // Regenerate current address
        if let wallet = self.wallet {
            let addressInfo = wallet.revealNextAddress(keychain: .external)
            currentBitcoinAddress = addressInfo.address.description
            saveAddressToKeychain(currentBitcoinAddress!)
            persist()
            results.append("   ✅ Fresh address generated: \(currentBitcoinAddress!)")
        }
        
        // Force complete UI refresh
        await forceCompleteWalletRefresh()
        results.append("   ✅ UI components refreshed")
        
        results.append("\n✅ FORCE REFRESH COMPLETED!")
        
        return results.joined(separator: "\n")
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
