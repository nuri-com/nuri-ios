import Foundation
import KeychainAccess
import LocalAuthentication

/// Manages secure storage and recovery of seed phrases
class SecureSeedManager {
    
    // Use the same keychain service as BitcoinWalletService to avoid duplicates
    private let keychain = Keychain(service: "com.nuri.bitcoin-wallet")
        .accessibility(.whenUnlocked)
        .synchronizable(true)
    
    // Use consistent key names with BitcoinWalletService
    private let seedKey = "bitcoin.wallet.mnemonic"
    private let backupSeedKey = "bitcoin.wallet.backup.mnemonic"
    private let timestampKey = "bitcoin.wallet.backup.timestamp"
    
    init() {
        print("🔐 [SecureSeedManager] Initializing with unified keychain configuration")
        print("   📦 Keychain Service: com.nuri.bitcoin-wallet")
        print("   ☁️ iCloud Sync: ENABLED")
        print("   🔓 Accessibility: .whenUnlocked")
        print("   📱 Face ID: Handled at app level")
    }
    
    /// Store seed phrase in keychain (Face ID already verified at app level)
    func storeWithBiometrics(seed: String) -> Bool {
        print("🔐 [SecureSeedManager] storeWithBiometrics() called")
        print("   📝 Seed length: \(seed.count) characters")
        
        // Check if this is a backup operation (different from main seed)
        do {
            // Check if main seed exists
            if let existingSeed = try keychain.get(seedKey) {
                if existingSeed == seed {
                    print("   ℹ️ Same seed already exists in keychain, skipping")
                    return true
                } else {
                    print("   📝 Different seed detected, storing as backup")
                    return storeBackupSeed(seed)
                }
            }
        } catch {
            print("   ℹ️ No existing seed found, proceeding with store")
        }
        
        // Store the seed
        do {
            print("   💾 Storing seed in keychain...")
            
            // Add timestamp
            let timestamp = Date().timeIntervalSince1970
            try keychain.set("\(timestamp)", key: timestampKey)
            
            // Store seed with label for visibility in Keychain Access
            try keychain
                .label("Nuri Bitcoin Wallet Seed")
                .comment("Recovery phrase for Nuri wallet - KEEP SECURE!")
                .set(seed, key: seedKey)
            
            print("   ✅ Seed stored successfully")
            print("   ✅ Timestamp: \(timestamp)")
            print("   📱 Synced to iCloud Keychain")
            
            return true
        } catch {
            print("   ❌ Failed to store seed: \(error)")
            return false
        }
    }
    
    /// Store a backup seed (for testing or recovery)
    private func storeBackupSeed(_ seed: String) -> Bool {
        do {
            print("   💾 Storing backup seed...")
            
            try keychain
                .label("Nuri Bitcoin Wallet Backup Seed")
                .comment("Backup recovery phrase")
                .set(seed, key: backupSeedKey)
            
            print("   ✅ Backup seed stored successfully")
            return true
        } catch {
            print("   ❌ Failed to store backup seed: \(error)")
            return false
        }
    }
    
    /// Recover seed phrase from keychain (Face ID already verified at app level)
    func recoverWithBiometrics() -> String? {
        print("🔓 [SecureSeedManager] recoverWithBiometrics() called")
        
        do {
            if let seed = try keychain.get(seedKey) {
                print("   ✅ Seed recovered successfully")
                print("   📝 Recovered seed length: \(seed.count) characters")
                return seed
            } else {
                print("   ❌ No seed found in keychain")
                
                // Try backup seed
                if let backupSeed = try keychain.get(backupSeedKey) {
                    print("   ✅ Backup seed found and recovered")
                    return backupSeed
                }
            }
        } catch {
            print("   ❌ Failed to recover seed: \(error)")
        }
        
        return nil
    }
    
    /// Check if seed exists in keychain
    func hasSeedInKeychain() -> Bool {
        do {
            let exists = try keychain.contains(seedKey)
            let hasBackup = try keychain.contains(backupSeedKey)
            
            print("🔍 [SecureSeedManager] Checking seed existence:")
            print("   Main seed: \(exists ? "✅ Found" : "❌ Not found")")
            print("   Backup seed: \(hasBackup ? "✅ Found" : "❌ Not found")")
            
            return exists || hasBackup
        } catch {
            print("❌ [SecureSeedManager] Failed to check seed existence: \(error)")
            return false
        }
    }
    
    /// Clear all data from keychain (for testing)
    func clearAllData() -> Bool {
        print("🗑️ [SecureSeedManager] Clearing keychain data...")
        
        do {
            // Note: We only clear backup keys, not the main wallet seed
            try keychain.remove(backupSeedKey)
            try keychain.remove(timestampKey)
            print("   ✅ Backup data cleared")
            print("   ℹ️ Main wallet seed preserved")
            return true
        } catch {
            print("   ⚠️ Clear error: \(error)")
            return false
        }
    }
    
    /// List all Bitcoin wallet related keys (for debugging)
    func listKeychainContents() {
        print("\n📋 [SecureSeedManager] Bitcoin wallet keychain contents:")
        
        do {
            let allKeys = try keychain.allKeys()
            for key in allKeys {
                if key.contains("bitcoin") || key.contains("wallet") {
                    if let value = try? keychain.get(key) {
                        let preview = key.contains("mnemonic") ? "[SEED - \(value.count) chars]" : value
                        print("   • \(key): \(preview)")
                    }
                }
            }
            
            if allKeys.isEmpty {
                print("   • No items found in keychain")
            }
        } catch {
            print("   • Error listing keychain: \(error)")
        }
    }
}