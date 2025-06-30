import SwiftUI

struct SecurityView: View {
    @State private var passkeyEnabled: Bool = true
    @State private var iCloudBackupEnabled: Bool = true

    var body: some View {
        Screen {
            // Header – displays screen title and CTA
            NuriHeader<AnyView, AnyView>.logoAndCTA(
                title: "",
                cta: "+ Add Key",
                onCTA: {}
            )
        } content: {
            // Body content fills the remaining space below the header
            VStack(spacing: 12) {
                NuriMenuRow(icon: "passkey-new",
                            title: "Passkey",
                            subtitle: "Account is secured with Apple iCloud Passkey.") {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color("PrimaryNuriBlack"))
                }

                NuriMenuRow(icon: "icloud-download",
                            title: "iCloud Backup",
                            subtitle: "We automatically saved a recovery key to iCloud.") {
                    Toggle("", isOn: $iCloudBackupEnabled)
                        .labelsHidden()
                        .tint(Color("PrimaryNuriLilac"))
                }

                NuriMenuRow(icon: "touch-id",
                            title: "Add Hardware Key",
                            subtitle: "Add a Nuri or Yubikey security key to your Account.") {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color("PrimaryNuriBlack"))
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0) // push action button toward bottom while still inside the body

            actionButton()
                .padding(.bottom, 34)
        }
    }

    // MARK: - Components

    private func actionButton() -> some View {
        Button(action: {
            // Add Passkey action
        }) {
            HStack(spacing: 8) {
                Image("passkey")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
                Text("Add a Passkey")
                    .font(.brandBody)
                    .foregroundColor(Color("PrimaryNuriBlack"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color("PrimaryNuriLilac"))
            .cornerRadius(32)
        }
        .padding(.horizontal, 24)
    }
}

#if DEBUG
struct SecurityView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityView()
    }
}
#endif
