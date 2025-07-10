import SwiftUI
import AuthenticationServices

struct SecurityView: View {
    @State private var authEnabled: Bool = true
    @State private var iCloudBackupEnabled: Bool = true
    @State private var showAuthOptions: Bool = false
    @State private var isLinkingAuth: Bool = false
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
                    icon: "lock",
                    title: "Authentication",
                    subtitle: authEnabled ? "Enabled" : "Disabled"
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
                
                // Authentication functionality removed - will be replaced with new integration
                

                
                Spacer()
            }
            .padding(.horizontal)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkingError ?? "An error occurred")
        }
        .confirmationDialog("Choose Authentication Type", isPresented: $showAuthOptions, titleVisibility: .visible) {
            Button("Platform Authentication (Face ID/Touch ID)") {
                // Platform authentication removed - will be replaced with new integration
                print("Platform authentication linking disabled")
            }
            
            Button("Hardware Security Key (YubiKey/FIDO2)") {
                // Hardware authentication removed - will be replaced with new integration
                print("Hardware authentication linking disabled")
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select the type of authentication you want to add to your account.")
        }
        .sheet(isPresented: $showSuccess) {
            SuccessView(
                illustration: "lock",
                title: "Success!",
                subtitle: "Your new authentication has been added",
                onDone: {
                    showSuccess = false
                }
            )
        }
        // Wallet info sheet removed - will be replaced with new integration
    }
    
    // MARK: - Authentication Functions removed
    // Authentication functionality will be replaced with new integration
    
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
