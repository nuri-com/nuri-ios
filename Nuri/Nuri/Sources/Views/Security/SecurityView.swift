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
                
                // Passkey functionality removed - will be replaced with new integration
                

                
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
                // linkPlatformPasskey() removed - will be replaced with new integration
                print("Platform passkey linking disabled")
            }
            
            Button("Hardware Security Key (YubiKey/FIDO2)") {
                // linkHardwarePasskey() removed - will be replaced with new integration
                print("Hardware passkey linking disabled")
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
        // Wallet info sheet removed - will be replaced with new integration
    }
    
    // MARK: - Passkey Functions removed
    // Passkey functionality will be replaced with new integration
    
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
