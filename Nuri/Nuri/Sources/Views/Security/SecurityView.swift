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
                        // Ethereum Wallet Section (Currently Supported)
                        NuriMenuRow(
                            icon: "wallet",
                            title: "Ethereum Wallet",
                            subtitle: walletAddress != nil ? 
                                String(walletAddress!.prefix(6) + "..." + walletAddress!.suffix(4)) : 
                                "Not created"
                        ) {
                            EmptyView()
                        }
                        
                        // Create Ethereum Wallet Button
                        if walletAddress == nil {
                            Button(action: createWallet) {
                                HStack {
                                    if isCreatingWallet {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                    }
                                    Text(isCreatingWallet ? "Creating Wallet..." : "Create Ethereum Wallet")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(isCreatingWallet)
                        }
                        
                        // Future Bitcoin Wallet Section (Placeholder)
                        VStack(alignment: .leading, spacing: 8) {
                            NuriMenuRow(
                                icon: "bitcoin-circle",
                                title: "Bitcoin Wallet (Future)",
                                subtitle: "Available when Privy adds native iOS support"
                            ) {
                                EmptyView()
                            }
                            
                            Text("🚀 Coming Soon: Native iOS Bitcoin wallet support")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 44) // Align with subtitle
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
                                        .foregroundColor(.secondary)
                                    
                                    Text(privateKey)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(4)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        
                        // Error Display
                        if let error = walletError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2)
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
        print("🔄 [SecurityView] Ensure wallet flow started …")
        isCreatingWallet = true
        walletError = nil

        // 1. Fetch current wallets first to avoid duplicates
        PrivyWorkaroundService.shared.getWallets { result in
            switch result {
            case .failure(let err):
                DispatchQueue.main.async {
                    self.walletError = "Fetch wallets failed: \(err.localizedDescription)"
                    self.isCreatingWallet = false
                }
            case .success(let wallets):
                // Separate ETH / BTC
                let eth = wallets.first { $0.chainType.lowercased() == "ethereum" }
                let btc = wallets.first { $0.chainType.lowercased().contains("bitcoin") }

                if let ethWallet = eth {
                    print("✅ Existing ETH wallet found: \(ethWallet.address)")
                    DispatchQueue.main.async { self.walletAddress = ethWallet.address }
                }

                // Closure helper to proceed with BTC creation after ETH ready
                func ensureBitcoin(using existingWallets: [PrivyWorkaroundService.WalletInfo]) {
                    if let btcWallet = existingWallets.first(where: { $0.chainType.lowercased().contains("bitcoin") }) {
                        print("✅ Bitcoin wallet already exists: \(btcWallet.address)")
                        DispatchQueue.main.async { self.isCreatingWallet = false }
                        return
                    }
                    print("🚀 No Bitcoin wallet – creating one …")
                    PrivyWorkaroundService.shared.createBitcoinWallet { createRes in
                        DispatchQueue.main.async {
                            self.isCreatingWallet = false
                            switch createRes {
                            case .success(let w):
                                print("✅ BTC wallet created: \(w.address)")
                            case .failure(let e):
                                print("❌ BTC wallet creation failed: \(e.localizedDescription)")
                                // Don't show the technical error to the user for Bitcoin wallets
                                // Since it's a known limitation, we'll handle it gracefully
                                if e.localizedDescription.contains("not yet supported") {
                                    print("ℹ️ Bitcoin wallet creation is pending native iOS support from Privy")
                                    // You could show a user-friendly message or just skip it
                                } else {
                                    self.walletError = "BTC create failed: \(e.localizedDescription)"
                                }
                            }
                        }
                    }
                }

                // If no ETH wallet yet, create it then call ensureBitcoin
                if eth == nil {
                    print("🚀 No Ethereum wallet – creating one …")
                    PrivyWorkaroundService.shared.createEthereumWallet { ethRes in
                        switch ethRes {
                        case .success(let newEth):
                            print("✅ ETH wallet created: \(newEth.address)")
                            DispatchQueue.main.async { self.walletAddress = newEth.address }
                            ensureBitcoin(using: wallets + [newEth])
                        case .failure(let err):
                            DispatchQueue.main.async {
                                self.walletError = "ETH create failed: \(err.localizedDescription)"
                                self.isCreatingWallet = false
                            }
                        }
                    }
                } else {
                    // ETH exists; now ensure Bitcoin
                    ensureBitcoin(using: wallets)
                }
            }
        }
    }
    
    private func performEthereumWalletCreation() {
        PrivyWorkaroundService.shared.createEmbeddedWallet { createResult in
            DispatchQueue.main.async {
                self.isCreatingWallet = false
                
                switch createResult {
                case .success(let wallet):
                    self.walletAddress = wallet.address
                    print("✅ [SecurityView] Ethereum wallet created successfully!")
                    print("   💳 Address: \(wallet.address)")
                    print("   ⛓️ Chain: \(wallet.chainType)")
                    print("   ✅ Verified: \(wallet.verified)")
                    
                case .failure(let error):
                    print("❌ [SecurityView] Ethereum wallet creation failed: \(error)")
                    
                    // Check for specific error types
                    if let nsError = error as NSError? {
                        if nsError.domain == "PrivyAuth" && nsError.code == 401 {
                            self.walletError = "Authentication expired. Please log in again."
                        } else if nsError.localizedDescription.contains("already exists") {
                            // Wallet already exists, try to fetch it
                            self.checkExistingWallet()
                            return
                        } else {
                            self.walletError = "Creation failed: \(nsError.localizedDescription)"
                        }
                    } else {
                        self.walletError = "Creation failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func checkExistingWallet() {
        print("🔍 [SecurityView] Checking for existing wallets...")
        
        // Check authentication first
        guard PrivyWorkaroundService.shared.isAuthenticated else {
            print("❌ [SecurityView] User not authenticated")
            return
        }
        
        // Get existing wallets
        PrivyWorkaroundService.shared.getWallets { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let wallets):
                    print("✅ [SecurityView] Got wallets: \(wallets.count)")
                    
                    // Look for Ethereum wallets specifically
                    let ethereumWallets = wallets.filter { $0.chainType.lowercased() == "ethereum" }
                    
                    if let ethWallet = ethereumWallets.first {
                        self.walletAddress = ethWallet.address
                        print("✅ [SecurityView] Using existing Ethereum wallet: \(ethWallet.address)")
                    } else {
                        print("💡 [SecurityView] No Ethereum wallet found. User needs to create one.")
                    }
                    
                case .failure(let error):
                    print("❌ [SecurityView] Failed to get wallets: \(error)")
                    self.walletError = "Failed to load wallets: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportPrivateKey() {
        print("🔑 [SecurityView] Private key export toggled")
        
        if showPrivateKey {
            // Hide the private key
            showPrivateKey = false
            walletPrivateKey = nil
        } else {
            // Show the private key
            // Note: In a real implementation, you would need to:
            // 1. Get the private key from Privy's wallet API
            // 2. Decrypt it using MPC
            // This is a placeholder implementation
            showPrivateKey = true
            walletPrivateKey = "Private key export requires MPC implementation"
            
            print("⚠️ [SecurityView] Private key export requires MPC implementation")
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
