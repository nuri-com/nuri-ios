import SwiftUI
import AuthenticationServices
import UIKit

struct SecurityView: View {
    @State private var resultText = "Press the button to test the encrypted iCloud backup."
    @State private var debugKeyText = "Press button to show encryption key info."
    @State private var isLoading = false
    @State private var showingExportOptions = false
    @State private var exportedKey = ""
    @State private var showingShareSheet = false
    @State private var importSeedPhrase = ""
    @State private var showingImportConfirmation = false
    @State private var showingLogoutConfirmation = false
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false
    private let bitcoinWalletService = BitcoinWalletService.shared
    


    var body: some View {
        Screen {
            // Header
            NuriHeader<AnyView, AnyView>.logoAndCTA(
                title: "Security (Updated)",
                cta: "",
                onCTA: {}
            )
        } content: {
            Form {
                Section(header: Text("Session Management")) {
                    Button(action: { showingLogoutConfirmation = true }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            Text("Log Out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("Device Encryption Key")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Each device has a unique encryption key:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(DeviceEncryptionService.shared.getDeviceKeyInfo())
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Button(action: { showingExportOptions = true }) {
                        Label("Export Encryption Key", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: testDeviceEncryption) {
                        Label("Test Device Encryption", systemImage: "lock.circle")
                    }
                }
                
                Section(header: Text("Passkey Backup")) {
                    Button(action: backupEncryptionKeyToPasskey) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Backing up...")
                            }
                        } else {
                            Label("Backup Encryption Key to Passkey", systemImage: "icloud.and.arrow.up")
                        }
                    }
                    .disabled(isLoading)
                    
                    Button(action: getEncryptionKeyFromPasskey) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Retrieving...")
                            }
                        } else {
                            Label("Get Encryption Key from Passkey", systemImage: "icloud.and.arrow.down")
                        }
                    }
                    .disabled(isLoading)
                    
                    if !resultText.isEmpty && resultText != "Press the button to test the encrypted iCloud backup." {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                Text(resultText)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 150)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
                
                Section(header: Text("Encryption Test Results")) {
                    VStack {
                        ScrollView {
                            Text(debugKeyText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(minHeight: 100)
                }
                
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
                    
                    Button(action: createManualBackup) {
                        Label("Create Manual Backup", systemImage: "icloud.and.arrow.up")
                    }
                    
                    Button(action: forceRestoreFromiCloud) {
                        Label("☁️ Force Restore from iCloud", systemImage: "icloud.and.arrow.down.fill")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: forceRefreshEverything) {
                        Label("🔄 Force Refresh Everything", systemImage: "arrow.clockwise.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("Seed Import & Testing")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Seed Phrase:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter 12-word seed phrase", text: $importSeedPhrase, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                        
                        Text("⚠️ WARNING: This will permanently overwrite your current wallet!")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: { showingImportConfirmation = true }) {
                        Label("🔄 Import & Overwrite Seed", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.orange)
                    }
                    .disabled(importSeedPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                Section(header: Text("Security Testing")) {
                    Button(action: testSecurityCleanup) {
                        Label("Test Security Cleanup (DEBUG)", systemImage: "shield.checkered")
                    }
                    
                    Button(action: comprehensiveStorageDiagnostic) {
                        Label("Comprehensive Storage Diagnostic", systemImage: "magnifyingglass.circle")
                    }
                    
                    Button(action: forceAggressiveCleanup) {
                        Label("🧹 FORCE AGGRESSIVE CLEANUP", systemImage: "trash.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .disabled(isLoading)
        }
        .sheet(isPresented: $showingExportOptions) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Export Encryption Key")
                        .font(.title2)
                        .bold()
                    
                    Text("This key encrypts your Bitcoin wallet. Save it securely!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Base64 Format:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let key = try? DeviceEncryptionService.shared.exportDeviceKey() {
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .onTapGesture {
                                    UIPasteboard.general.string = key
                                }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Button(action: exportAsTextFile) {
                            Label("Save as Text File", systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: exportAsQRCode) {
                            Label("Show QR Code", systemImage: "qrcode")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationBarItems(trailing: Button("Done") {
                    showingExportOptions = false
                })
            }
        }
        .alert("Confirm Seed Import", isPresented: $showingImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import", role: .destructive) {
                importSeedPhraseAction()
            }
        } message: {
            Text("This will permanently overwrite your current wallet with the imported seed phrase. This action cannot be undone!\n\nCurrent wallet data will be lost forever.")
        }
        .alert("Log Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to log out? You'll need to authenticate with your passkey to log back in.")
        }
    }
    
    private func testDeviceEncryption() {
        debugKeyText = "Testing device-specific encryption..."
        Task {
            let result = await Task.detached {
                do {
                    let testData = "test seed phrase: abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
                    
                    // Test encryption
                    let encrypted = try DeviceEncryptionService.shared.encrypt(data: testData)
                    
                    // Test decryption
                    let decrypted = try DeviceEncryptionService.shared.decrypt(encryptedBase64: encrypted)
                    
                    // Verify
                    let matches = testData == decrypted
                    
                    return """
                    🧪 DEVICE ENCRYPTION TEST:
                    
                    ✅ Original: \(testData)
                    🔐 Encrypted: \(encrypted.prefix(50))...
                    🔓 Decrypted: \(decrypted)
                    🎯 Match: \(matches ? "✅ SUCCESS" : "❌ FAILED")
                    
                    Device Key Info:
                    \(DeviceEncryptionService.shared.getDeviceKeyInfo())
                    """
                } catch {
                    return "❌ Device encryption test failed: \(error)"
                }
            }.value
            await MainActor.run {
                debugKeyText = result
            }
        }
    }
    
    private func testDecryption() {
        isLoading = true
        resultText = "Initiating decryption...\n\nPlease use Face ID / Touch ID when prompted."
        Task {
            let result = await bitcoinWalletService.testDecryptCloudBackup()
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
    private func testSecurityCleanup() {
        isLoading = true
        resultText = "Testing security cleanup (no files will be deleted)..."
        Task {
            let result = await Task.detached {
                return bitcoinWalletService.testSecurityCleanup()
            }.value
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
    private func comprehensiveStorageDiagnostic() {
        isLoading = true
        resultText = "Running comprehensive storage diagnostic..."
        Task {
            let result = await Task.detached {
                return bitcoinWalletService.comprehensiveStorageDiagnostic()
            }.value
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
    private func forceAggressiveCleanup() {
        isLoading = true
        resultText = "🧹 FORCE AGGRESSIVE CLEANUP\n\nThis will clear ALL wallet data from ALL keychain services and Documents directory.\n\nExecuting..."
        Task {
            await Task.detached {
                bitcoinWalletService.forceCleanAllKeychainServices()
            }.value
            await MainActor.run {
                self.resultText = "🧹 AGGRESSIVE CLEANUP COMPLETED!\n\n✅ All keychain services cleared\n✅ Documents directory cleared\n✅ All wallet data removed\n\n⚠️ Next wallet creation will be completely fresh!\n\n🔄 Restart the app to test fresh wallet creation."
                self.isLoading = false
            }
        }
    }
    
    private func createManualBackup() {
        isLoading = true
        resultText = "Creating manual iCloud backup...\n\nThis will encrypt current seed phrase and store in iCloud keychain."
        Task {
            let result = await Task.detached {
                return self.bitcoinWalletService.createManualBackup()
            }.value
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
    private func importSeedPhraseAction() {
        let seedToImport = importSeedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !seedToImport.isEmpty else {
            resultText = "❌ Error: Seed phrase cannot be empty"
            return
        }
        
        isLoading = true
        resultText = "🔄 IMPORTING SEED PHRASE...\n\n⚠️ This will permanently overwrite your current wallet!\n\nProcessing..."
        
        Task {
            let result = await bitcoinWalletService.importAndOverwriteSeed(newSeedPhrase: seedToImport)
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
                
                // Clear the input field after successful import
                if result.contains("✅ IMPORT COMPLETED SUCCESSFULLY!") {
                    self.importSeedPhrase = ""
                }
            }
        }
    }
    
    private func forceRestoreFromiCloud() {
        isLoading = true
        resultText = "☁️ FORCE RESTORE FROM ICLOUD...\n\nThis will clear all local data and restore from iCloud backup.\n\nProcessing..."
        
        Task {
            let result = await bitcoinWalletService.forceRestoreFromiCloudBackup()
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
    private func forceRefreshEverything() {
        isLoading = true
        resultText = "🔄 FORCE REFRESH EVERYTHING...\n\nClearing all cache and refreshing wallet state...\n\nProcessing..."
        
        Task {
            let result = await bitcoinWalletService.forceRefreshEverything()
            await MainActor.run {
                self.resultText = result
                self.isLoading = false
            }
        }
    }
    
    private func performLogout() {
        Log.ui.info("User logging out")
        
        // Clear the login state
        isUserLoggedIn = false
        
        Log.ui.success("Logout completed - user will see welcome screen")
    }
    
    private func exportAsTextFile() {
        guard let key = try? DeviceEncryptionService.shared.exportDeviceKey() else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = dateFormatter.string(from: Date())
        
        let content = """
        Nuri Wallet Encryption Key
        ==========================
        Device: \(UIDevice.current.name)
        Created: \(Date())
        
        IMPORTANT: This key encrypts your Bitcoin wallet.
        Keep it safe! Without this key, you cannot recover your wallet.
        
        Encryption Key (Base64):
        \(key)
        
        Instructions:
        1. Save this file in a secure location
        2. Do NOT share this key with anyone
        3. You'll need this key to restore your wallet on a new device
        """
        
        // Create temporary file
        let fileName = "nuri-encryption-key-\(dateString).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Share the file
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to create export file: \(error)")
        }
    }
    
    private func exportAsQRCode() {
        // This would show a QR code view - for now just copy to clipboard
        if let key = try? DeviceEncryptionService.shared.exportDeviceKey() {
            UIPasteboard.general.string = key
            // In a real implementation, you'd show a QR code here
        }
    }
    
    // MARK: - Passkey Backup Functions
    
    private func backupEncryptionKeyToPasskey() {
        Log.ui.info("===== BACKUP ENCRYPTION KEY TO PASSKEY =====")
        Log.ui.info("User initiated manual backup of encryption key")
        
        isLoading = true
        resultText = ""
        
        Task {
            do {
                // Get current user info from UserDefaults (set during login)
                guard let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
                    Log.ui.error("No username found in UserDefaults")
                    await MainActor.run {
                        resultText = "❌ Error: Not logged in with passkey"
                        isLoading = false
                    }
                    return
                }
                
                let credentialId = UserDefaults.standard.string(forKey: "passkeyCredentialId")
                let isAnonymous = UserDefaults.standard.bool(forKey: "passkeyIsAnonymous")
                
                Log.ui.info("Backing up for user", metadata: [
                    "username": username,
                    "isAnonymous": isAnonymous,
                    "hasCredentialId": credentialId != nil
                ])
                
                // Backup the encryption key
                try await PasskeyAuthenticationService.shared.storeEncryptionKey(
                    for: username,
                    credentialId: credentialId,
                    isAnonymous: isAnonymous
                )
                
                Log.ui.success("Encryption key backed up successfully")
                
                await MainActor.run {
                    resultText = """
                    ✅ SUCCESS: Encryption key backed up to passkey server
                    
                    Username: \(username)
                    Anonymous: \(isAnonymous)
                    Timestamp: \(Date())
                    
                    Your encryption key is now safely backed up with your passkey.
                    You can recover it on any device using your passkey.
                    """
                    isLoading = false
                }
                
            } catch {
                Log.ui.error("Failed to backup encryption key", error: error)
                await MainActor.run {
                    resultText = "❌ Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func getEncryptionKeyFromPasskey() {
        Log.ui.info("===== GET ENCRYPTION KEY FROM PASSKEY =====")
        Log.ui.info("User initiated retrieval of encryption key")
        
        isLoading = true
        resultText = ""
        
        Task {
            do {
                // Get current user info from UserDefaults
                guard let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
                    Log.ui.error("No username found in UserDefaults")
                    await MainActor.run {
                        resultText = "❌ Error: Not logged in with passkey"
                        isLoading = false
                    }
                    return
                }
                
                let credentialId = UserDefaults.standard.string(forKey: "passkeyCredentialId")
                let isAnonymous = UserDefaults.standard.bool(forKey: "passkeyIsAnonymous")
                
                Log.ui.info("Retrieving key for user", metadata: [
                    "username": username,
                    "isAnonymous": isAnonymous,
                    "hasCredentialId": credentialId != nil
                ])
                
                // Retrieve the encryption key
                if let retrievedKey = try await PasskeyAuthenticationService.shared.retrieveEncryptionKey(
                    for: username,
                    credentialId: credentialId,
                    isAnonymous: isAnonymous
                ) {
                    Log.ui.success("Encryption key retrieved successfully", metadata: [
                        "keyLength": retrievedKey.count
                    ])
                    
                    // Compare with current device key
                    let currentKey = try? DeviceEncryptionService.shared.exportDeviceKey()
                    let keysMatch = currentKey == retrievedKey
                    
                    Log.ui.info("Key comparison", metadata: [
                        "keysMatch": keysMatch,
                        "currentKeyExists": currentKey != nil
                    ])
                    
                    await MainActor.run {
                        resultText = """
                        ✅ SUCCESS: Encryption key retrieved from passkey server
                        
                        Username: \(username)
                        Anonymous: \(isAnonymous)
                        
                        Retrieved Key:
                        \(retrievedKey)
                        
                        Status: \(keysMatch ? "✅ Matches current device key" : "⚠️ Different from current device key")
                        
                        ⚠️ IMPORTANT: Save this key securely if you need to recover your wallet on another device!
                        """
                        isLoading = false
                    }
                } else {
                    Log.ui.warning("No encryption key found on server")
                    await MainActor.run {
                        resultText = """
                        ⚠️ No encryption key found on passkey server
                        
                        Username: \(username)
                        
                        This user has not backed up their encryption key yet.
                        Use "Backup Encryption Key to Passkey" to create a backup.
                        """
                        isLoading = false
                    }
                }
                
            } catch {
                Log.ui.error("Failed to retrieve encryption key", error: error)
                await MainActor.run {
                    resultText = "❌ Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
