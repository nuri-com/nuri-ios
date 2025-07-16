import SwiftUI
import AuthenticationServices

struct SecurityView: View {
    @State private var resultText = "Press the button to test the encrypted iCloud backup."
    @State private var debugKeyText = "Press button to show encryption key info."
    @State private var isLoading = false
    @State private var currentPassword = ""
    @State private var editingPassword = false
    @State private var importSeedPhrase = ""
    @State private var showingImportConfirmation = false
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
                Section(header: Text("Password Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Password:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if editingPassword {
                            HStack {
                                TextField("Enter password", text: $currentPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button("Save") {
                                    SimpleEncryptionService.shared.setPassword(currentPassword)
                                    editingPassword = false
                                }
                                Button("Cancel") {
                                    currentPassword = SimpleEncryptionService.shared.getCurrentPassword()
                                    editingPassword = false
                                }
                            }
                        } else {
                            HStack {
                                Text(currentPassword)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                Spacer()
                                Button("Edit") {
                                    editingPassword = true
                                }
                            }
                        }
                    }
                    
                    Button(action: testSimpleEncryption) {
                        Label("Test Simple Encryption", systemImage: "lock.circle")
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
        .onAppear {
            currentPassword = SimpleEncryptionService.shared.getCurrentPassword()
        }
        .alert("Confirm Seed Import", isPresented: $showingImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import", role: .destructive) {
                importSeedPhraseAction()
            }
        } message: {
            Text("This will permanently overwrite your current wallet with the imported seed phrase. This action cannot be undone!\n\nCurrent wallet data will be lost forever.")
        }
    }
    
    private func testSimpleEncryption() {
        debugKeyText = "Testing simple encryption with hardcoded password..."
        Task {
            let result = await Task.detached {
                return SimpleEncryptionService.shared.testRoundtrip(testData: "test seed phrase: abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
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
    
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
