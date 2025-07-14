import SwiftUI
import AuthenticationServices

struct SecurityView: View {
    @State private var keysEnabled: Bool = true
    @State private var iCloudBackupEnabled: Bool = true
    @State private var showKeysOptions: Bool = false
    @State private var isLinkingKeys: Bool = false
    @State private var linkingError: String?
    @State private var showAlert: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showWalletInfo: Bool = false
    
    // Seed storage management
    @State private var alertMessage = ""
    @State private var showKeychainAlert = false
    @State private var showManualSeedEntry = false
    @State private var manualSeedPhrase = ""
    private let bitcoinWalletService = BitcoinWalletService.shared
    


    var body: some View {
        Screen {
            // Header – displays screen title and CTA
            NuriHeader<AnyView, AnyView>.logoAndCTA(
                title: "",
                cta: "+ Add Key",
                onCTA: {}
            )
        } content: {
            // Body content fills the screen between header and footer
            VStack(spacing: 16) {
            
                NuriMenuRow(
                    icon: "passkey-new",
                    title: "Keys",
                    subtitle: keysEnabled ? "Enabled" : "Disabled"
                ) {
                    Image(systemName: "chevron.right")
                }

                NuriMenuRow(
                    icon: "wallet",
                    title: "Wallet Keys",
                    subtitle: "2-of-2 multi-signature"
                ) {
                    Image(systemName: "chevron.right")
                }
                
                NuriMenuRow(
                    icon: "icloud-download",
                    title: "iCloud backup",
                    subtitle: iCloudBackupEnabled ? "Enabled" : "Disabled"
                ) {
                    Toggle("", isOn: $iCloudBackupEnabled)
                        .labelsHidden()
                        .tint(Color("PrimaryNuriLilac"))
                }
                
                // Seed Storage Options
                NuriMenuRow(
                    icon: "key",
                    title: "Store Seed in Keychain",
                    subtitle: "Secure biometric backup"
                ) {
                    Button("Store") {
                        storeTestSeed()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("PrimaryNuriLilac"))
                }
                
                NuriMenuRow(
                    icon: "key",
                    title: "Recover Seed from Keychain",
                    subtitle: "Restore from backup"
                ) {
                    Button("Recover") {
                        recoverTestSeed()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("PrimaryNuriLilac"))
                }
                
                // Debug: Verify Keychain
                NuriMenuRow(
                    icon: "checkmark.circle",
                    title: "Verify Keychain Sync",
                    subtitle: "Check Mac visibility"
                ) {
                    Button("Verify") {
                        verifyKeychainSync()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                }
                
                // Debug: Test Independent Storage
                NuriMenuRow(
                    icon: "hammer",
                    title: "Test Keychain (Debug)",
                    subtitle: "Test with fake seed"
                ) {
                    Button("Test") {
                        testIndependentKeychain()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkingError ?? "An error occurred")
        }
        .alert("Biometric Keychain Test", isPresented: $showKeychainAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Choose Key Type", isPresented: $showKeysOptions, titleVisibility: .visible) {
            Button("Platform Passkey (Face ID/Touch ID)") {
                // linkPlatformPasskey() removed - will be replaced with new integration
                print("Platform passkey linking disabled")
            }
            
            Button("Hardware Security Key (YubiKey/FIDO2)") {
                // linkHardwarePasskey() removed - will be replaced with new integration
                print("Hardware passkey linking disabled")
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select the type of key you want to add to your account.")
        }
        .sheet(isPresented: $showSuccess) {
            SuccessView(
                illustration: "passkey-new",
                title: "Success!",
                subtitle: "Your new key has been added",
                onDone: {
                    showSuccess = false
                }
            )
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
