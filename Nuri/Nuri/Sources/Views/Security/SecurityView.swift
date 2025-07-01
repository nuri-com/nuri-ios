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
    @State private var showWalletInfo: Bool = false
    


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
                    title: "Passkeys",
                    subtitle: passkeyEnabled ? "Enabled" : "Disabled"
                ) {
                    Image(systemName: "chevron.right")
                }

                Button(action: {
                    showWalletInfo = true
                }) {
                    NuriMenuRow(
                        icon: "wallet",
                        title: "Wallet Info",
                        subtitle: "2-of-2 multi-signature"
                    ) {
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                NuriMenuRow(
                    icon: "icloud-download",
                    title: "iCloud backup",
                    subtitle: iCloudBackupEnabled ? "Enabled" : "Disabled"
                ) {
                    Toggle("", isOn: $iCloudBackupEnabled)
                        .labelsHidden()
                        .tint(Color("PrimaryNuriLilac"))
                }
                
                // Add a Passkey button
                actionButton()
                    .padding(.top, 10)
                

                
                Spacer()
            }
            .padding(.horizontal)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkingError ?? "An error occurred")
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
        .sheet(isPresented: $showWalletInfo) {
            PrivyWallet(onClose: {
                showWalletInfo = false
            })
        }
    }
    
    // MARK: - Passkey Functions
    
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
