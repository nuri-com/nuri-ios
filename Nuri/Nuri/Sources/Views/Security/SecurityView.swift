import SwiftUI
import AuthenticationServices
import UIKit
import Photos
import StrigaAPI

struct SecurityView: View {
    @State private var resultText = "Press the button to test the encrypted iCloud backup."
    @State private var debugKeyText = "Press button to show encryption key info."
    @State private var isLoading = false
    @State private var showingExportOptions = false
    @State private var exportedKey = ""
    @State private var showingShareSheet = false
    @State private var showingQRCode = false
    @State private var qrCodeImage: UIImage?
    @State private var importSeedPhrase = ""
    @State private var showingImportConfirmation = false
    @State private var showingLogoutConfirmation = false
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false
    @State private var userPasskeys: [PasskeyAuthenticationService.UserPasskeysResponse.PasskeyInfo] = []
    @State private var passkeyStrigaUserId: String?
    @State private var strigaUserData: StrigaUserData?
    @State private var isLoadingStrigaUser = false
    private let bitcoinWalletService = BitcoinWalletService.shared
    private let striga = StrigaService.shared
    
    // Temporary struct until Xcode picks up the new files
    struct StrigaUserData {
        let userId: String
        let email: String
        let firstName: String
        let lastName: String
        let mobile: (countryCode: String, number: String)?
        let kycStatus: String
        let createdAt: String
    }
    
    // Encryption verification state
    @AppStorage("encryptionKeyVerified") var encryptionKeyVerified: Bool = false
    @AppStorage("hasLocalEncryptionKey") var hasLocalEncryptionKey: Bool = false
    @AppStorage("hasServerBackup") var hasServerBackup: Bool = false
    @AppStorage("hasWalletBackup") var hasWalletBackup: Bool = false
    @AppStorage("encryptionKeysMatch") var encryptionKeysMatch: Bool = false
    @AppStorage("canDecryptWallet") var canDecryptWallet: Bool = false
    


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
                
                Section(header: Text("User Debug Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        // App Login State
                        HStack {
                            Text("App Login State:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(isUserLoggedIn ? "✅ Logged In" : "❌ Not Logged In")
                                .font(.caption.bold())
                        }
                        
                        Divider()
                        
                        // Passkey Information
                        Text("Passkey Information:")
                            .font(.caption.bold())
                            .padding(.top, 4)
                        
                        if let username = UserDefaults.standard.string(forKey: "passkeyUsername") {
                            Text("Username: \(username)")
                                .font(.caption)
                        } else {
                            Text("Username: Not set")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if let credentialId = UserDefaults.standard.string(forKey: "passkeyCredentialId") {
                            Text("Credential ID: \(credentialId.prefix(20))...")
                                .font(.caption)
                        } else {
                            Text("Credential ID: Not set")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Text("Anonymous: \(UserDefaults.standard.bool(forKey: "passkeyIsAnonymous") ? "Yes" : "No")")
                            .font(.caption)
                        
                        Divider()
                        
                        // Striga Information
                        Text("Striga Information:")
                            .font(.caption.bold())
                            .padding(.top, 4)
                        
                        if let strigaUserId = UserSettings().strigaUserId {
                            Text("Striga User ID: \(strigaUserId)")
                                .font(.caption)
                                .textSelection(.enabled)
                            Text("Card Status: ✅ Has Card")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Striga User ID: Not set")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("Card Status: ❌ No Card")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Passkey Server Striga ID
                        if let passkeyStrigaId = passkeyStrigaUserId {
                            Text("Passkey Server Striga ID: \(passkeyStrigaId)")
                                .font(.caption)
                                .textSelection(.enabled)
                                .foregroundColor(.blue)
                        } else {
                            Text("Passkey Server Striga ID: Not synced")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Striga Session (temporary data during card creation)
                        if let sessionUserId = StrigaSession.shared.userId {
                            Text("Session User ID: \(sessionUserId)")
                                .font(.caption)
                        }
                        if let sessionName = StrigaSession.shared.name {
                            Text("Session Name: \(sessionName)")
                                .font(.caption)
                        }
                        if let sessionAddress = StrigaSession.shared.address {
                            Text("Session Address: \(sessionAddress.addressLine1), \(sessionAddress.city)")
                                .font(.caption)
                        }
                        
                        Divider()
                        
                        // Bitcoin Wallet State
                        Text("Bitcoin Wallet:")
                            .font(.caption.bold())
                            .padding(.top, 4)
                        
                        Text("Has Wallet: \(bitcoinWalletService.hasWallet() ? "✅ Yes" : "❌ No")")
                            .font(.caption)
                        
                        Text("Balance: \(WalletStateManager.shared.balance.confirmed) sats")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Debug actions
                    Button(action: resetStrigaState) {
                        Label("Reset Striga Card State", systemImage: "creditcard.slash")
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
                
                Section(header: Text("Striga User Data")) {
                    VStack(alignment: .leading, spacing: 12) {
                        strigaStoredDataView()
                        Divider()
                        strigaSessionDataView()
                        Divider()
                        strigaConfigurationView()
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Section(header: Text("Encryption Key Verification Status")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Security Checks:")
                            .font(.caption.bold())
                            .padding(.bottom, 4)
                        
                        // Local encryption key check
                        HStack {
                            Image(systemName: hasLocalEncryptionKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(hasLocalEncryptionKey ? .green : .red)
                                .font(.system(size: 20))
                            VStack(alignment: .leading) {
                                Text("Local Encryption Key")
                                    .font(.caption.bold())
                                Text("Device has encryption key for wallet protection")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Server backup check
                        HStack {
                            Image(systemName: hasServerBackup ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(hasServerBackup ? .green : .red)
                                .font(.system(size: 20))
                            VStack(alignment: .leading) {
                                Text("Server Backup")
                                    .font(.caption.bold())
                                Text("Encryption key is backed up with passkey")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Wallet backup check
                        HStack {
                            Image(systemName: hasWalletBackup ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(hasWalletBackup ? .green : .red)
                                .font(.system(size: 20))
                            VStack(alignment: .leading) {
                                Text("Wallet Backup")
                                    .font(.caption.bold())
                                Text("Encrypted wallet backup exists in iCloud")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Keys match check
                        HStack {
                            Image(systemName: encryptionKeysMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(encryptionKeysMatch ? .green : .red)
                                .font(.system(size: 20))
                            VStack(alignment: .leading) {
                                Text("Key Synchronization")
                                    .font(.caption.bold())
                                Text("Server and local encryption keys match")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Can decrypt check
                        HStack {
                            Image(systemName: canDecryptWallet ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(canDecryptWallet ? .green : .red)
                                .font(.system(size: 20))
                            VStack(alignment: .leading) {
                                Text("Wallet Decryption")
                                    .font(.caption.bold())
                                Text("Can decrypt wallet with current key")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        // Overall status
                        if encryptionKeyVerified {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.green)
                                    .font(.system(size: 24))
                                VStack(alignment: .leading) {
                                    Text("All Security Checks Passed")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                    Text("Your wallet encryption is properly configured")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                            .padding(12)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 24))
                                VStack(alignment: .leading) {
                                    Text("Security Issues Detected")
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)
                                    Text("Some encryption checks failed. Please review.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Manual verification button
                        Button(action: runManualVerification) {
                            if isLoading {
                                HStack {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Running verification...")
                                }
                            } else {
                                Label("Run Manual Verification", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 4)
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
                
                Section(header: Text("Quick Backup Options")) {
                    VStack(spacing: 12) {
                        // QR Code
                        Button(action: {
                            if let key = try? DeviceEncryptionService.shared.exportDeviceKey(),
                               let qrImage = generateQRCode(from: key) {
                                qrCodeImage = qrImage
                                showingQRCode = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "qrcode")
                                    .frame(width: 30)
                                Text("Save as QR Code")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // iCloud Drive
                        Button(action: saveToiCloudDrive) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                    .frame(width: 30)
                                Text("Save to iCloud Drive")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Google Drive
                        Button(action: saveToGoogleDrive) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                    .frame(width: 30)
                                Text("Save to Google Drive")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Text File
                        Button(action: exportAsTextFile) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .frame(width: 30)
                                Text("Export as Text File")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section(header: Text("Passkey Backup")) {
                    // Show registered passkeys if logged in
                    if isUserLoggedIn && !userPasskeys.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Registered Passkeys:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(userPasskeys, id: \.credentialId) { passkey in
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(passkey.deviceName ?? "Unknown Device")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("ID: \(passkey.credentialId.prefix(20))...")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        if let lastUsed = passkey.lastUsed {
                                            Text("Last used: \(lastUsed)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                    }
                    
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
                    
                    // Add Additional Passkey button
                    Button(action: addAdditionalPasskey) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Adding passkey...")
                            }
                        } else {
                            Label("Add Another Device/Passkey", systemImage: "person.badge.plus")
                        }
                    }
                    .disabled(isLoading || !isUserLoggedIn)
                    
                    // Add Hardware Security Key button
                    Button(action: addHardwareSecurityKey) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Adding security key...")
                            }
                        } else {
                            Label("Add Hardware Security Key", systemImage: "key.horizontal.fill")
                        }
                    }
                    .disabled(isLoading || !isUserLoggedIn)
                    
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
                        
                        Button(action: saveToiCloudDrive) {
                            Label("Save to iCloud Drive", systemImage: "icloud.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: saveToGoogleDrive) {
                            Label("Save to Google Drive", systemImage: "folder.badge.plus")
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
        .onAppear {
            loadUserPasskeys()
            
            // Run verification check on view load
            Task {
                let result = await bitcoinWalletService.verifyEncryptionKeyIntegrity()
                
                await MainActor.run {
                    // Update UserDefaults with latest results
                    UserDefaults.standard.set(result.isFullyVerified, forKey: "encryptionKeyVerified")
                    UserDefaults.standard.set(result.hasLocalEncryptionKey, forKey: "hasLocalEncryptionKey")
                    UserDefaults.standard.set(result.hasServerBackup, forKey: "hasServerBackup")
                    UserDefaults.standard.set(result.hasEncryptedWalletBackup, forKey: "hasWalletBackup")
                    UserDefaults.standard.set(result.keysMatch, forKey: "encryptionKeysMatch")
                    UserDefaults.standard.set(result.canDecryptWallet, forKey: "canDecryptWallet")
                }
            }
            
            // Auto-fetch Striga user data if we have a userId
            if let userId = UserSettings().strigaUserId {
                Task {
                    await fetchStrigaUser(userId: userId)
                }
            }
        }
        .sheet(isPresented: $showingQRCode) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Encryption Key QR Code")
                        .font(.title2)
                        .bold()
                    
                    Text("Save this QR code to recover your wallet on another device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if let qrImage = qrCodeImage {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                    
                    VStack(spacing: 10) {
                        Button(action: saveQRToPhotos) {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: shareQRCode) {
                            Label("Share QR Code", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    Text("⚠️ Keep this QR code secure! It can decrypt your wallet.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationBarItems(trailing: Button("Done") {
                    showingQRCode = false
                })
            }
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
    
    private func resetStrigaState() {
        // Clear Striga user ID to reset card state
        UserSettings().strigaUserId = nil
        
        // Clear ALL Striga session data
        StrigaSession.shared.userId = nil
        StrigaSession.shared.cardId = nil
        StrigaSession.shared.name = nil
        StrigaSession.shared.email = nil
        StrigaSession.shared.phoneNumber = nil
        StrigaSession.shared.phoneCountryCode = nil
        StrigaSession.shared.address = nil
        StrigaSession.shared.dateOfBirth = nil
        
        // Generate unique test email for next attempt
        let timestamp = Int(Date().timeIntervalSince1970)
        let testEmail = "test+\(timestamp)@nuri.com"
        
        resultText = """
        ✅ Striga State Reset Complete:
        
        - Striga User ID cleared
        - All session data cleared
        - Card tab will now show "No Card" view
        
        For testing, you can use this unique email:
        \(testEmail)
        
        ⚠️ Note: Since we can't delete Striga users, each test needs a unique email.
        The phone number can be reused.
        
        You can now go through the card creation flow again.
        """
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
        guard let key = try? DeviceEncryptionService.shared.exportDeviceKey() else { return }
        
        // Generate QR code
        if let qrImage = generateQRCode(from: key) {
            qrCodeImage = qrImage
            showingExportOptions = false
            showingQRCode = true
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
            
            if let output = filter.outputImage {
                // Scale up the QR code for better quality
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledOutput = output.transformed(by: transform)
                
                // Convert to UIImage
                let context = CIContext()
                if let cgImage = context.createCGImage(scaledOutput, from: scaledOutput.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        
        return nil
    }
    
    private func saveQRToPhotos() {
        guard let image = qrCodeImage else { return }
        
        // Check photo library permission
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                
                DispatchQueue.main.async {
                    // Show success message
                    self.resultText = """
                    ✅ QR Code saved to Photos!
                    
                    The QR code containing your encryption key has been saved to your photo library.
                    
                    ⚠️ IMPORTANT:
                    - Keep this QR code secure
                    - Anyone with this QR code can decrypt your wallet
                    - Consider storing it in a locked note or secure location
                    - Delete from Recently Deleted after saving elsewhere
                    """
                    
                    self.showingQRCode = false
                }
            } else {
                DispatchQueue.main.async {
                    self.resultText = """
                    ❌ Photo Library Access Denied
                    
                    Please enable photo library access in Settings to save the QR code.
                    
                    Go to Settings > Nuri > Photos and enable access.
                    """
                    
                    self.showingQRCode = false
                }
            }
        }
    }
    
    private func shareQRCode() {
        guard let image = qrCodeImage else { return }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Find the presented view controller (the sheet)
            var presentingVC = rootVC
            while let presented = presentingVC.presentedViewController {
                presentingVC = presented
            }
            
            presentingVC.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Cloud Storage Functions
    
    private func saveToiCloudDrive() {
        guard let key = try? DeviceEncryptionService.shared.exportDeviceKey() else {
            resultText = "❌ Failed to export encryption key"
            return
        }
        
        // Create the encryption key data with metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let content = """
        Nuri Wallet Encryption Key
        ==========================
        Created: \(Date())
        Device: \(UIDevice.current.name)
        
        IMPORTANT: This key encrypts your Bitcoin wallet.
        Keep it safe! Without this key, you cannot recover your wallet.
        
        Encryption Key (Base64):
        \(key)
        
        Instructions:
        1. This key is required to decrypt your Bitcoin wallet
        2. Store this file in a secure location
        3. Do NOT share this key with anyone
        4. You'll need this key to restore your wallet on a new device
        
        Security Notice:
        - This is NOT your Bitcoin private key
        - This is the encryption key that protects your Bitcoin private key
        - Both this encryption key AND your passkey are required to access your wallet
        """
        
        // Create temporary file
        let fileName = "nuri-encryption-key-\(dateString).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Create document picker for saving to iCloud Drive
            let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
            documentPicker.shouldShowFileExtensions = true
            
            // Present the document picker
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                
                // Dismiss export options first
                showingExportOptions = false
                
                // Present document picker after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    rootVC.present(documentPicker, animated: true) {
                        self.resultText = """
                        📤 Ready to save to iCloud Drive
                        
                        Choose a location in iCloud Drive to save your encryption key.
                        
                        Recommended: Create a folder called "Nuri Backup" for organization.
                        """
                    }
                }
            }
        } catch {
            resultText = "❌ Failed to create export file: \(error.localizedDescription)"
        }
    }
    
    private func saveToGoogleDrive() {
        guard let key = try? DeviceEncryptionService.shared.exportDeviceKey() else {
            resultText = "❌ Failed to export encryption key"
            return
        }
        
        // Create the encryption key data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let content = """
        Nuri Wallet Encryption Key
        ==========================
        Created: \(Date())
        Device: \(UIDevice.current.name)
        
        IMPORTANT: This key encrypts your Bitcoin wallet.
        Keep it safe! Without this key, you cannot recover your wallet.
        
        Encryption Key (Base64):
        \(key)
        
        Instructions:
        1. This key is required to decrypt your Bitcoin wallet
        2. Store this file in a secure location
        3. Do NOT share this key with anyone
        4. You'll need this key to restore your wallet on a new device
        """
        
        // Create temporary file
        let fileName = "nuri-encryption-key-\(dateString).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // For Google Drive, we'll use the share sheet with specific apps
            let activityItems: [Any] = [tempURL]
            let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            
            // Suggest specific apps including Google Drive
            activityVC.excludedActivityTypes = [
                .addToReadingList,
                .assignToContact,
                .openInIBooks,
                .postToFacebook,
                .postToTwitter,
                .postToWeibo,
                .postToFlickr,
                .postToVimeo,
                .postToTencentWeibo
            ]
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                
                // Dismiss export options first
                showingExportOptions = false
                
                // Present share sheet after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    rootVC.present(activityVC, animated: true) {
                        self.resultText = """
                        📤 Share to Google Drive
                        
                        Select "Save to Files" or "Google Drive" from the share sheet.
                        
                        If Google Drive app is installed, it will appear as an option.
                        Otherwise, you can save to Files and manually upload to Google Drive later.
                        """
                    }
                }
            }
        } catch {
            resultText = "❌ Failed to create export file: \(error.localizedDescription)"
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
    
    // MARK: - Add Additional Passkey
    
    private func addAdditionalPasskey() {
        Log.ui.info("===== ADD ADDITIONAL PASSKEY =====")
        Log.ui.info("User initiated adding additional passkey")
        
        isLoading = true
        resultText = "Adding additional passkey...\n\nPlease follow the prompts to register a new passkey for your existing account."
        
        Task {
            do {
                // Get current user info
                guard let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
                    Log.ui.error("No username found - user must be logged in first")
                    await MainActor.run {
                        resultText = "❌ Error: You must be logged in to add additional passkeys"
                        isLoading = false
                    }
                    return
                }
                
                let isAnonymous = UserDefaults.standard.bool(forKey: "passkeyIsAnonymous")
                
                Log.ui.info("Adding passkey for existing user", metadata: [
                    "username": username,
                    "isAnonymous": isAnonymous
                ])
                
                // Get the window for passkey presentation
                guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = await windowScene.windows.first(where: { $0.isKeyWindow }) else {
                    Log.ui.error("Could not find window for passkey presentation")
                    await MainActor.run {
                        resultText = "❌ Error: Could not present passkey dialog"
                        isLoading = false
                    }
                    return
                }
                
                // Create a new passkey for the existing user
                // The username parameter ensures the new passkey is linked to the same account
                let result = try await PasskeyAuthenticationService.shared.createPasskey(
                    username: isAnonymous ? nil : username,
                    presentationAnchor: window
                )
                
                if result.verified {
                    Log.ui.success("Additional passkey created successfully", metadata: [
                        "username": result.username ?? "unknown"
                    ])
                    
                    await MainActor.run {
                        resultText = """
                        ✅ SUCCESS: Additional passkey added!
                        
                        Username: \(result.username ?? username)
                        Total Passkeys: Multiple devices can now access this account
                        
                        You can now use this device to:
                        - Access your wallet
                        - Recover your encryption key
                        - Make transactions
                        
                        All your passkeys share the same:
                        - Bitcoin wallet
                        - Encryption key backup
                        - Account data
                        """
                        isLoading = false
                    }
                } else {
                    Log.ui.error("Failed to verify additional passkey")
                    await MainActor.run {
                        resultText = "❌ Error: Failed to create additional passkey"
                        isLoading = false
                        // Refresh the passkeys list
                        loadUserPasskeys()
                    }
                }
                
            } catch {
                Log.ui.error("Failed to add additional passkey", error: error)
                await MainActor.run {
                    resultText = "❌ Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Add Hardware Security Key
    
    private func addHardwareSecurityKey() {
        Log.ui.info("===== ADD HARDWARE SECURITY KEY =====")
        Log.ui.info("User initiated adding hardware security key")
        
        isLoading = true
        resultText = "Adding hardware security key...\n\nPlease connect your security key (e.g., YubiKey) and follow the prompts."
        
        Task {
            do {
                // Get current user info
                guard let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
                    Log.ui.error("No username found - user must be logged in first")
                    await MainActor.run {
                        resultText = "❌ Error: You must be logged in to add a security key"
                        isLoading = false
                    }
                    return
                }
                
                let isAnonymous = UserDefaults.standard.bool(forKey: "passkeyIsAnonymous")
                
                Log.ui.info("Adding security key for existing user", metadata: [
                    "username": username,
                    "isAnonymous": isAnonymous
                ])
                
                // Get the window for passkey presentation
                guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = await windowScene.windows.first(where: { $0.isKeyWindow }) else {
                    Log.ui.error("Could not find window for security key presentation")
                    await MainActor.run {
                        resultText = "❌ Error: Could not present security key dialog"
                        isLoading = false
                    }
                    return
                }
                
                // Add security key ONLY (no platform passkey)
                let result = try await PasskeyAuthenticationService.shared.addSecurityKey(
                    username: isAnonymous ? nil : username,
                    presentationAnchor: window
                )
                
                if result.verified {
                    Log.ui.success("Hardware security key added successfully", metadata: [
                        "username": result.username ?? "unknown"
                    ])
                    
                    await MainActor.run {
                        resultText = """
                        ✅ SUCCESS: Hardware security key added!
                        
                        Username: \(result.username ?? username)
                        
                        Your hardware security key (e.g., YubiKey) is now registered.
                        
                        You can now use this security key to:
                        - Authenticate to your wallet
                        - Access your encryption key backup
                        - Make transactions
                        
                        Security keys provide an extra layer of protection and work across all your devices.
                        """
                        isLoading = false
                        // Refresh the passkeys list
                        loadUserPasskeys()
                    }
                } else {
                    Log.ui.error("Failed to verify hardware security key")
                    await MainActor.run {
                        resultText = "❌ Error: Failed to add hardware security key"
                        isLoading = false
                    }
                }
                
            } catch {
                Log.ui.error("Failed to add hardware security key", error: error)
                await MainActor.run {
                    resultText = """
                    ❌ Error: \(error.localizedDescription)
                    
                    Make sure:
                    - Your security key is connected
                    - You're using a FIDO2/WebAuthn compatible key
                    - The key is not already registered
                    """
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Load User Passkeys
    
    private func runManualVerification() {
        Log.ui.info("===== MANUAL ENCRYPTION KEY VERIFICATION =====")
        Log.ui.info("User initiated manual verification of encryption keys")
        
        isLoading = true
        
        Task {
            // Run comprehensive verification
            let result = await bitcoinWalletService.verifyEncryptionKeyIntegrity()
            
            await MainActor.run {
                isLoading = false
                
                // Update UserDefaults with latest results
                UserDefaults.standard.set(result.isFullyVerified, forKey: "encryptionKeyVerified")
                UserDefaults.standard.set(result.hasLocalEncryptionKey, forKey: "hasLocalEncryptionKey")
                UserDefaults.standard.set(result.hasServerBackup, forKey: "hasServerBackup")
                UserDefaults.standard.set(result.hasEncryptedWalletBackup, forKey: "hasWalletBackup")
                UserDefaults.standard.set(result.keysMatch, forKey: "encryptionKeysMatch")
                UserDefaults.standard.set(result.canDecryptWallet, forKey: "canDecryptWallet")
                
                // Provide user feedback
                if result.isFullyVerified {
                    resultText = "✅ All encryption key checks passed!\n\nYour wallet encryption is properly configured and synchronized."
                } else {
                    var issues: [String] = []
                    if !result.hasLocalEncryptionKey {
                        issues.append("❌ No local encryption key found")
                    }
                    if !result.hasServerBackup {
                        issues.append("❌ Encryption key not backed up on server")
                    }
                    if !result.hasEncryptedWalletBackup {
                        issues.append("❌ No encrypted wallet backup in iCloud")
                    }
                    if !result.keysMatch {
                        issues.append("❌ Server and local keys don't match")
                    }
                    if !result.canDecryptWallet {
                        issues.append("❌ Cannot decrypt wallet with current key")
                    }
                    
                    resultText = "⚠️ Encryption verification failed:\n\n" + issues.joined(separator: "\n")
                    if let error = result.errorMessage {
                        resultText += "\n\nError: \(error)"
                    }
                }
                
                Log.ui.info("Verification complete", metadata: [
                    "fullyVerified": result.isFullyVerified,
                    "hasLocalKey": result.hasLocalEncryptionKey,
                    "hasServerBackup": result.hasServerBackup,
                    "hasWalletBackup": result.hasEncryptedWalletBackup,
                    "keysMatch": result.keysMatch,
                    "canDecrypt": result.canDecryptWallet
                ])
            }
        }
    }
    
    private func loadUserPasskeys() {
        guard isUserLoggedIn,
              let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
            return
        }
        
        Task {
            do {
                let passkeys = try await PasskeyAuthenticationService.shared.getUserPasskeys(for: username)
                await MainActor.run {
                    self.userPasskeys = passkeys
                    Log.ui.info("Loaded passkeys", metadata: ["count": passkeys.count])
                }
                
                // Also load the Striga user ID from passkey server
                await loadPasskeyStrigaUserId()
            } catch {
                Log.ui.error("Failed to load passkeys", error: error)
            }
        }
    }
    
    private func loadPasskeyStrigaUserId() async {
        guard let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
            return
        }
        
        let credentialId = UserDefaults.standard.string(forKey: "passkeyCredentialId")
        let isAnonymous = UserDefaults.standard.bool(forKey: "passkeyIsAnonymous")
        
        do {
            // Try to retrieve user data from passkey server
            let identifier = username
            var urlString = "\(PasskeyAuthenticationService.shared.baseURL)/api/users/\(identifier)/data"
            
            if isAnonymous, let credentialId = credentialId {
                urlString += "?credentialId=\(credentialId)"
            }
            
            guard let url = URL(string: urlString) else {
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }
            
            if let userData = try? JSONDecoder().decode(PasskeyAuthenticationService.UserDataGetResponse.self, from: data),
               let encryptedData = userData.encryptedData,
               let strigaUserId = encryptedData.strigaUserId {
                await MainActor.run {
                    self.passkeyStrigaUserId = strigaUserId
                    Log.ui.info("Loaded Striga user ID from passkey server", metadata: ["strigaUserId": strigaUserId])
                }
            }
        } catch {
            Log.ui.error("Failed to load Striga user ID from passkey server", error: error)
        }
    }
    
    // MARK: - Striga View Components
    
    @ViewBuilder
    private func strigaStoredDataView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("💳 Stored User Data")
                    .font(.caption.bold())
                
                Spacer()
                
                if let userId = UserSettings().strigaUserId {
                    Button(action: {
                        Task {
                            await fetchStrigaUser(userId: userId)
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isLoadingStrigaUser {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                            }
                            Text("Refresh")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            
            if let userId = UserSettings().strigaUserId {
                HStack {
                    Text("User ID:")
                        .font(.caption.bold())
                    Text(userId)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            
            // Display fetched user data
            if let userData = strigaUserData {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Name (Session):")
                            .font(.caption.bold())
                        Text("\(userData.firstName) \(userData.lastName)")
                            .font(.caption)
                            .foregroundColor(userData.firstName == "John" && userData.lastName == "Mock-Doe" ? .red : .green)
                    }
                    
                    if userData.firstName == "John" && userData.lastName == "Mock-Doe" {
                        Text("⚠️ WARNING: Default name detected!")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Email:")
                            .font(.caption.bold())
                        Text(userData.email)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    
                    if let mobile = userData.mobile {
                        HStack {
                            Text("API Phone:")
                                .font(.caption.bold())
                            Text("\(mobile.countryCode) \(mobile.number)")
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Text("KYC Status:")
                            .font(.caption.bold())
                        Text(userData.kycStatus)
                            .font(.caption)
                            .foregroundColor(userData.kycStatus == "APPROVED" ? .green : .orange)
                    }
                    
                    HStack {
                        Text("Created:")
                            .font(.caption.bold())
                        Text(userData.createdAt)
                            .font(.caption2)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
            
            if let cardId = UserSettings().strigaCardId {
                HStack {
                    Text("Card ID:")
                        .font(.caption.bold())
                    Text(cardId)
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundColor(cardId == "mock-card-id" ? .red : .primary)
                }
                if cardId == "mock-card-id" {
                    Text("⚠️ Mock card detected - needs real card creation")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            
            if let walletId = UserSettings().strigaWalletId {
                HStack {
                    Text("Wallet ID:")
                        .font(.caption.bold())
                    Text(walletId)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    @ViewBuilder
    private func strigaSessionDataView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📝 Current Session Data")
                .font(.caption.bold())
            
            if let sessionUserId = StrigaSession.shared.userId {
                HStack {
                    Text("Session User ID:")
                        .font(.caption.bold())
                    Text(sessionUserId)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            
            if let name = StrigaSession.shared.name {
                HStack {
                    Text("Name:")
                        .font(.caption.bold())
                    Text(name)
                        .font(.caption)
                }
            }
            
            if let firstName = StrigaSession.shared.firstName,
               let lastName = StrigaSession.shared.lastName {
                HStack {
                    Text("Full Name:")
                        .font(.caption.bold())
                    Text("\(firstName) \(lastName)")
                        .font(.caption)
                }
            }
            
            if let email = StrigaSession.shared.email {
                HStack {
                    Text("Email:")
                        .font(.caption.bold())
                    Text(email)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            
            if let phoneNumber = StrigaSession.shared.phoneNumber,
               let phoneCountryCode = StrigaSession.shared.phoneCountryCode {
                HStack {
                    Text("Phone:")
                        .font(.caption.bold())
                    Text("+\(phoneCountryCode)\(phoneNumber)")
                        .font(.caption)
                }
            }
            
            if let dob = StrigaSession.shared.dateOfBirth {
                HStack {
                    Text("Date of Birth:")
                        .font(.caption.bold())
                    Text("\(dob.day)/\(dob.month)/\(dob.year)")
                        .font(.caption)
                }
            }
            
            if let address = StrigaSession.shared.address {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Address:")
                        .font(.caption.bold())
                    Text(address.addressLine1)
                        .font(.caption2)
                    Text("\(address.postalCode) \(address.city)")
                        .font(.caption2)
                    Text(address.country)
                        .font(.caption2)
                }
            }
        }
    }
    
    @ViewBuilder
    private func strigaConfigurationView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("⚙️ API Configuration")
                .font(.caption.bold())
            
            if let config = StrigaService.shared.configuration {
                HStack {
                    Text("URL:")
                        .font(.caption.bold())
                    Text(config.url)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("API Key:")
                        .font(.caption.bold())
                    Text(String(config.key.prefix(20)) + "...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Not configured")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    @MainActor
    private func fetchStrigaUser(userId: String) async {
        isLoadingStrigaUser = true
        strigaUserData = nil
        
        do {
            // Configure Striga if not already configured
            if striga.configuration == nil {
                striga.configuration = StrigaConfiguration(
                    url: "https://www.sandbox.striga.com/api/",
                    key: "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=",
                    secret: "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE="
                )
                print("[SecurityView] Configured Striga for sandbox environment")
            }
            
            print("[SecurityView] Fetching user data for userId: \(userId)")
            
            // TODO: Uncomment when Xcode recognizes the new GetUser files
            // let response = try await striga.getUser(.init(userId: userId))
            
            // For now, check session data to verify the fix
            if let firstName = StrigaSession.shared.firstName,
               let lastName = StrigaSession.shared.lastName,
               let email = StrigaSession.shared.email {
                
                print("[SecurityView] Using session data:")
                print("  - Name: \(firstName) \(lastName)")
                print("  - Email: \(email)")
                
                // Create temporary data from session
                strigaUserData = StrigaUserData(
                    userId: userId,
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    mobile: nil,
                    kycStatus: "PENDING",
                    createdAt: "Check API when available"
                )
                
                // Check for John Mock-Doe issue
                if firstName == "John" && lastName == "Mock-Doe" {
                    print("[SecurityView] ⚠️ WARNING: John Mock-Doe detected in session data!")
                }
            } else {
                print("[SecurityView] No session data available")
                // Show what we have
                strigaUserData = StrigaUserData(
                    userId: userId,
                    email: StrigaSession.shared.email ?? "Unknown",
                    firstName: StrigaSession.shared.firstName ?? "Unknown",
                    lastName: StrigaSession.shared.lastName ?? "Unknown",
                    mobile: nil,
                    kycStatus: "Unknown",
                    createdAt: "N/A"
                )
            }
        } catch {
            print("[SecurityView] Error fetching user data: \(error)")
            if let validationError = error as? ValidationErrorResponse {
                print("[SecurityView] Validation error: \(validationError.message)")
            }
        }
        
        isLoadingStrigaUser = false
    }
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
