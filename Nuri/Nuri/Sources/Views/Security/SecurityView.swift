import SwiftUI
import AuthenticationServices

struct SecurityView: View {
    @State private var resultText = "Press the button to test the encrypted iCloud backup."
    @State private var isLoading = false
    private let bitcoinWalletService = BitcoinWalletService.shared
    


    var body: some View {
        Screen {
            // Header
            NuriHeader<AnyView, AnyView>.logoAndCTA(
                title: "Security",
                cta: "",
                onCTA: {}
            )
        } content: {
            Form {
                Section(header: Text("Test Results")) {
                    VStack {
                        if isLoading {
                            ProgressView("Performing test...")
                        } else {
                            ScrollView {
                                Text(resultText)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(minHeight: 150)
                }
                
                Section(header: Text("Backup & Recovery Verification")) {
                    Button(action: testDecryption) {
                        Label("Test Decrypt iCloud Backup", systemImage: "lock.open.display")
                    }
                }
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - Debug Methods
    
    private func storeTestSeed() {
        print("🔐 [SecurityView] Store seed button pressed")
        
        // Get the actual wallet seed if available
        let walletService = BitcoinWalletService.shared
        
        // Check if wallet is initialized
        if !walletService.hasWallet() {
            alertMessage = "⚠️ No wallet found\n\nPlease go to the Bitcoin tab first to create a wallet."
            showKeychainAlert = true
            return
        }
        
        // Get the actual seed phrase
        guard let actualSeed = walletService.seedPhrase() else {
            alertMessage = "❌ Failed to retrieve wallet seed"
            showKeychainAlert = true
            return
        }
        
        // Store the actual seed
        let seedManager = SecureSeedManager()
        let success = seedManager.storeWithBiometrics(seed: actualSeed)
        
        if success {
            alertMessage = "✅ Wallet seed backed up successfully!\n\nYour seed is now synced to iCloud Keychain."
        } else {
            alertMessage = "❌ Failed to backup seed."
        }
        showKeychainAlert = true
    }
    
    private func recoverTestSeed() {
        print("🔓 [SecurityView] Attempting to recover wallet seed from keychain...")
        
        let seedManager = SecureSeedManager()
        if let recoveredSeed = seedManager.recoverWithBiometrics() {
            // Only show first and last few words for security
            let words = recoveredSeed.split(separator: " ")
            let preview = words.count > 4 ? 
                "\(words[0]) \(words[1]) ... \(words[words.count-2]) \(words[words.count-1])" : 
                recoveredSeed
            
            alertMessage = "✅ Wallet seed recovered successfully:\n\n\(preview)\n\n(\(words.count) words total)"
        } else {
            alertMessage = "❌ No seed found in keychain.\n\nMake sure you have backed up a seed first."
        }
        showKeychainAlert = true
    }
    
    private func verifyKeychainSync() {
        print("🔍 [SecurityView] Verifying keychain sync status...")
        
        var message = "📱 Keychain Sync Status:\n\n"
        
        // Check if seed exists
        let seedManager = SecureSeedManager()
        let exists = seedManager.hasSeedInKeychain()
        message += "Seed stored: \(exists ? "✅ Yes" : "❌ No")\n\n"
        
        // Instructions for Mac
        message += "🖥️ To check on Mac:\n"
        message += "1. Open Keychain Access app\n"
        message += "2. Select 'iCloud' keychain\n"
        message += "3. Search for: com.nuri.secure-seed-backup.sync\n\n"
        
        message += "⚠️ Note: Sync may take a few minutes\n"
        message += "Make sure iCloud Keychain is enabled on both devices"
        
        alertMessage = message
        showKeychainAlert = true
    }
    
    private func testIndependentKeychain() {
        print("\n🧪 [SecurityView] INDEPENDENT KEYCHAIN TEST START")
        print("================================================")
        
        // Create a test seed that's different from wallet seed
        let testSeed = "test seed phrase that is completely different from wallet seed independent verification"
        print("📝 Test seed: \(testSeed)")
        
        // Create a separate test manager to ensure independence
        let testManager = SecureSeedManager()
        
        // Step 1: Clear any existing test data
        print("\n1️⃣ Clearing existing data...")
        _ = testManager.clearAllData()
        
        // Step 2: Store test seed
        print("\n2️⃣ Storing test seed...")
        let storeSuccess = testManager.storeWithBiometrics(seed: testSeed)
        print("Store result: \(storeSuccess ? "✅ SUCCESS" : "❌ FAILED")")
        
        // Step 3: Try to recover WITHOUT using BitcoinWalletService
        print("\n3️⃣ Recovering test seed...")
        if let recovered = testManager.recoverWithBiometrics() {
            print("✅ Recovered: \(recovered)")
            
            if recovered == testSeed {
                print("✅ PERFECT MATCH! Keychain is working correctly")
                alertMessage = "✅ Test PASSED!\n\nStored: \(testSeed)\nRecovered: \(recovered)\n\nKeychain is working!"
            } else {
                print("❌ MISMATCH! Something is wrong")
                alertMessage = "❌ Test FAILED!\n\nStored: \(testSeed)\nRecovered: \(recovered)\n\nThey don't match!"
            }
        } else {
            print("❌ Recovery failed")
            alertMessage = "❌ Test FAILED!\n\nCould not recover test seed from keychain"
        }
        
        print("\n🧪 INDEPENDENT KEYCHAIN TEST END")
        print("================================================\n")
        
        showKeychainAlert = true
    }
    
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
