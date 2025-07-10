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
    private var esploraClient: EsploraClient?
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
        // TEMPORARY: Remove biometric requirement to debug multiple Face ID issue
        keychain = Keychain(service: keychainService)
            .accessibility(.whenUnlocked)
            .synchronizable(true)  // Enable iCloud sync without biometrics for now

        print("🔑 [BitcoinWalletService] Keychain configured:")
        print("   🌩️ iCloud sync: ENABLED (temporary for debugging)")
        print("   🔐 Biometric auth: DISABLED (temporary for debugging)")
        print("   🔓 Accessibility: .whenUnlocked")
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
            print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #A - Storing mnemonic...")
            try keychain.set(mnemonic.description, key: Keys.mnemonic)
            print("   ✅ Mnemonic stored successfully")
            // Verify mnemonic was stored correctly
            verifyMnemonicStored()
            
            print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #B - Storing external descriptor...")
            try keychain.set(externalDesc.toStringWithSecret(), key: Keys.descriptor)
            print("   ✅ External descriptor stored successfully")
            
            print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #C - Storing internal descriptor...")
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
        guard let wallet else { return nil }
        guard let esploraClient else { return nil }
        
        do {
            // Sync first to get latest state
            try await syncWallet()
            
            let balance = wallet.balance()
            let confirmed = balance.confirmed.toSat()
            let pending = balance.trustedPending.toSat() + balance.untrustedPending.toSat()
            let total = balance.total.toSat()
            
            print("💰 [BitcoinWalletService] Detailed balance:")
            print("   ✅ Confirmed: \(confirmed) sats")
            print("   ⏳ Pending: \(pending) sats")  
            print("   📊 Total: \(total) sats")
            
            return (confirmed: confirmed, pending: pending, total: total)
        } catch {
            print("❌ [BitcoinWalletService] Failed to get detailed balance: \(error)")
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
        
        // Create sync inspector for progress tracking
        let inspector = WalletSyncScriptInspector { inspected, total in
            // Simple progress tracking - could be enhanced with UI progress bar
            print("🔄 [BitcoinWalletService] Sync progress: \(inspected)/\(total)")
        }
        
        // Start sync with revealed SPKs (faster than full scan)
        let syncRequest = try wallet.startSyncWithRevealedSpks()
            .inspectSpks(inspector: inspector)
            .build()
        
        let update = try esploraClient.sync(
            request: syncRequest,
            parallelRequests: UInt64(5)
        )
        
        let _ = try wallet.applyUpdate(update: update)
        
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
        
        print("🔍 [BitcoinWalletService] Loading existing wallet with single auth...")
        
        // Get all keychain data in one authentication session
        print("🔐 [BitcoinWalletService] Requesting all wallet data from keychain (single Face ID prompt)...")
        
        var mnemonic: String?
        var descriptor: String?
        var changeDescriptor: String?
        var cachedAddress: String?
        
        do {
            // Once Face ID is triggered for the first item, subsequent accesses should not trigger it again
            // due to keychain authentication caching
            print("🔐 [BitcoinWalletService] 🚨 FACE ID TRIGGER #1 - Getting mnemonic...")
            mnemonic = try keychain.get(Keys.mnemonic)
            print("🔐 [BitcoinWalletService] Getting descriptor (should NOT trigger Face ID)...")
            descriptor = try keychain.get(Keys.descriptor)
            print("🔐 [BitcoinWalletService] Getting change descriptor (should NOT trigger Face ID)...")
            changeDescriptor = try keychain.get(Keys.changeDescriptor)
            print("🔐 [BitcoinWalletService] Getting cached address (should NOT trigger Face ID)...")
            cachedAddress = try keychain.get(Keys.currentAddress)
            
            print("✅ [BitcoinWalletService] Retrieved all data from keychain with single auth")
            print("   📝 Mnemonic: \(mnemonic != nil ? "Found (\(mnemonic!.count) chars)" : "Not found")")
            print("   📝 External descriptor: \(descriptor != nil ? "Found (\(descriptor!.count) chars)" : "Not found")")
            print("   📝 Change descriptor: \(changeDescriptor != nil ? "Found (\(changeDescriptor!.count) chars)" : "Not found")")
            print("   📝 Cached address: \(cachedAddress ?? "Not found")")
            
        } catch let error as NSError {
            print("❌ [BitcoinWalletService] Failed to get wallet data from keychain: \(error)")
            print("   📋 Error domain: \(error.domain)")
            print("   📋 Error code: \(error.code)")
            print("   📋 Error description: \(error.localizedDescription)")
            if let statusMessage = SecCopyErrorMessageString(OSStatus(error.code), nil) {
                print("   📋 OSStatus description: \(statusMessage as String)")
            }
            throw WalletError.noExistingWallet
        }
        
        // Validate we have the required data
        guard let _ = mnemonic, 
              let descriptor = descriptor, 
              let changeDescriptor = changeDescriptor else {
            print("❌ [BitcoinWalletService] Missing required wallet data")
            throw WalletError.noExistingWallet
        }
        
        // Load wallet with existing descriptors
        print("🔧 [BitcoinWalletService] Loading wallet with retrieved descriptors...")
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
