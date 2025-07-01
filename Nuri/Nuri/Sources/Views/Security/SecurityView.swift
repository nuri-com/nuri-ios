import SwiftUI
import AuthenticationServices

struct SecurityView: View {
    @State private var passkeyEnabled: Bool = true
    @State private var iCloudBackupEnabled: Bool = true
    @State private var showPasskeyOptions: Bool = false
    @State private var isLinkingPasskey: Bool = false
    @State private var linkingError: String?
    @State private var showAlert: Bool = false
    @State private var showSuccess: Bool = false
    
    // Wallet management states
    @State private var isCreatingWallet: Bool = false
    @State private var walletAddress: String?
    @State private var walletPrivateKey: String?
    @State private var showPrivateKey: Bool = false
    @State private var walletError: String?

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Security")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                NuriMenuRow(
                    icon: "passkey-new",
                    title: "Passkey",
                    subtitle: passkeyEnabled ? "Enabled" : "Disabled"
                ) {
                    Toggle("", isOn: $passkeyEnabled)
                        .labelsHidden()
                }
                
                NuriMenuRow(
                    icon: "icloud-download",
                    title: "iCloud backup",
                    subtitle: iCloudBackupEnabled ? "Enabled" : "Disabled"
                ) {
                    Toggle("", isOn: $iCloudBackupEnabled)
                        .labelsHidden()
                }
                
                // Add a Passkey button
                actionButton()
                    .padding(.top, 10)
                
                // Wallet Management Section
                if PrivyWorkaroundService.shared.isAuthenticated {
                    VStack(spacing: 16) {
                        // Wallet Creation Section
                        NuriMenuRow(
                            icon: "wallet",
                            title: "Wallet",
                            subtitle: walletAddress != nil ? 
                                String(walletAddress!.prefix(6) + "..." + walletAddress!.suffix(4)) : 
                                "Not created"
                        ) {
                            EmptyView()
                        }
                        
                        // Create Wallet Button
                        if walletAddress == nil {
                            Button(action: createWallet) {
                                HStack {
                                    if isCreatingWallet {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.8)
                                    }
                                    Text(isCreatingWallet ? "Creating Wallet..." : "Create Wallet")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isCreatingWallet)
                        }
                        
                        // Export Private Key Button
                        if walletAddress != nil {
                            Button(action: exportPrivateKey) {
                                Text(showPrivateKey ? "Hide Private Key" : "Export Private Key")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            // Show Private Key
                            if showPrivateKey, let privateKey = walletPrivateKey {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Private Key:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(privateKey)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkingError ?? walletError ?? "An error occurred")
        }
        .confirmationDialog("Choose Passkey Type", isPresented: $showPasskeyOptions, titleVisibility: .visible) {
            Button("Platform Passkey (Face ID/Touch ID)") {
                linkPlatformPasskey()
            }
            
            Button("Hardware Security Key (YubiKey/FIDO2)") {
                linkHardwarePasskey()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select the type of passkey you want to add to your account.")
        }
        .sheet(isPresented: $showSuccess) {
            SuccessView(
                illustration: "passkey-new",
                title: "Success!",
                subtitle: "Your new passkey has been added",
                onDone: {
                    showSuccess = false
                }
            )
        }
    }
    
    // MARK: - Wallet Functions
    
    private func createWallet() {
        print("🔄 [SecurityView] Starting wallet creation...")
        isCreatingWallet = true
        walletError = nil
        
        // First, let's check our authentication status
        print("📊 [SecurityView] Authentication check:")
        print("   ✅ Is authenticated: \(PrivyWorkaroundService.shared.isAuthenticated)")
        print("   👤 User ID: \(PrivyWorkaroundService.shared.currentUserId ?? "nil")")
        
        let tokens = PasskeyService.getStoredTokens()
        print("   🎫 Access token: \(tokens.0?.prefix(20) ?? "nil")...")
        print("   🔄 Refresh token: \(tokens.1?.prefix(20) ?? "nil")...")
        
        // Check if user already has wallets first
        PrivyWorkaroundService.shared.getWallets { result in
            switch result {
            case .success(let wallets):
                print("📊 [SecurityView] User has \(wallets.count) existing wallets")
                
                if let existingWallet = wallets.first {
                    DispatchQueue.main.async {
                        self.walletAddress = existingWallet.address
                        self.isCreatingWallet = false
                        print("✅ [SecurityView] Using existing wallet: \(existingWallet.address)")
                    }
                    return
                }
                
                // No wallets found, create a new one
                print("🔨 [SecurityView] No existing wallets, creating new wallet...")
                self.performWalletCreation()
                
            case .failure(let error):
                print("⚠️ [SecurityView] Failed to check existing wallets: \(error)")
                
                // If checking existing wallets failed due to rate limiting, don't try to create
                if let nsError = error as NSError?,
                   nsError.domain == "PrivyAuth",
                   nsError.code == -3,
                   let errorString = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
                   errorString.contains("Too many requests") {
                    DispatchQueue.main.async {
                        self.isCreatingWallet = false
                        self.walletError = "Rate limited. Please wait a moment and try again."
                        self.showAlert = true
                    }
                    return
                }
                
                // For other errors, still try to create a wallet
                print("🔨 [SecurityView] Check failed, attempting wallet creation anyway...")
                self.performWalletCreation()
            }
        }
    }
    
    private func performWalletCreation() {
        PrivyWorkaroundService.shared.createEmbeddedWallet { createResult in
            DispatchQueue.main.async {
                self.isCreatingWallet = false
                
                switch createResult {
                case .success(let wallet):
                    self.walletAddress = wallet.address
                    print("✅ [SecurityView] Wallet created successfully!")
                    print("   💳 Address: \(wallet.address)")
                    print("   ⛓️ Chain: \(wallet.chainType)")
                    print("   ✅ Verified: \(wallet.verified)")
                    
                case .failure(let error):
                    print("❌ [SecurityView] Wallet creation failed: \(error)")
                    
                    // Check for specific error types
                    if let nsError = error as NSError? {
                        if nsError.domain == "PrivyAuth" && nsError.code == -3 {
                            if let errorMessage = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                                if errorMessage.contains("Too many requests") {
                                    self.walletError = "Rate limited. Please wait a moment and try again."
                                } else if errorMessage.contains("already exists") || errorMessage.contains("duplicate") {
                                    self.walletError = "Wallet already exists. Please refresh to see it."
                                } else {
                                    self.walletError = "API Error: \(errorMessage)"
                                }
                            } else {
                                self.walletError = "API Error: Unknown error"
                            }
                        } else {
                            self.walletError = error.localizedDescription
                        }
                    } else {
                        self.walletError = error.localizedDescription
                    }
                    
                    self.showAlert = true
                }
            }
        }
    }
    
    private func exportPrivateKey() {
        print("🔑 [SecurityView] Export private key toggled")
        
        if showPrivateKey {
            // Hide the private key
            showPrivateKey = false
            walletPrivateKey = nil
        } else {
            // Show the private key
            // Note: In a real implementation, you would need to:
            // 1. Get the private key from Privy's API
            // 2. Decrypt it using MPC
            // This is a placeholder implementation
            showPrivateKey = true
            walletPrivateKey = "Private key export requires MPC implementation"
            
            print("⚠️ [SecurityView] Private key export requires MPC implementation")
            print("   ℹ️ Privy uses MPC (Multi-Party Computation) for security")
            print("   ℹ️ The private key is split into shares and requires special handling")
        }
    }
    
    // MARK: - Original Functions
    
    private func actionButton() -> some View {
        Button(action: {
            print("🔘 [SecurityView] Add a Passkey button tapped")
            
            // Check if user is authenticated via stored tokens
            if PrivyWorkaroundService.shared.isAuthenticated {
                print("✅ [SecurityView] User is authenticated via tokens")
                print("   👤 User ID: \(PrivyWorkaroundService.shared.currentUserId ?? "nil")")
                showPasskeyOptions = true
            } else {
                print("❌ [SecurityView] User is not authenticated")
                showAlert = true
                linkingError = "Please sign in first before adding additional passkeys"
            }
        }) {
            NuriButton(
                icon: "touch-id",
                title: "Add a Passkey",
                style: .primary
            )
        }
        .padding(.horizontal, 24)
    }
    
    private func linkPlatformPasskey() {
        print("🔐 [SecurityView] Linking platform passkey...")
        isLinkingPasskey = true
        linkingError = nil
        
        PasskeyAuthCoordinator.shared.linkAdditionalPasskey { result in
            DispatchQueue.main.async {
                self.isLinkingPasskey = false
                
                switch result {
                case .success:
                    print("✅ [SecurityView] Platform passkey linked successfully")
                    self.showSuccess = true
                case .failure(let error):
                    print("❌ [SecurityView] Failed to link platform passkey: \(error)")
                    self.linkingError = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    private func linkHardwarePasskey() {
        print("🔐 [SecurityView] Linking hardware passkey...")
        isLinkingPasskey = true
        linkingError = nil
        
        // Hardware keys would need special handling or web-based flow
        // For now, show that it's not supported
        self.linkingError = "Hardware security keys require special handling not yet implemented"
        self.showAlert = true
        self.isLinkingPasskey = false
    }
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
