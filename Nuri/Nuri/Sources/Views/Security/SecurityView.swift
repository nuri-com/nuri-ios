import SwiftUI

struct SecurityView: View {
    @State private var passkeyEnabled: Bool = true
    @State private var iCloudBackupEnabled: Bool = true

    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                topNavigationBar()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                    .padding(.top, 44)

                ScrollView {
                    VStack(spacing: 21) {
                        Text("Security")
                            .font(.brandTitle1)
                            .foregroundColor(Color("PrimaryNuriBlack"))
                            .multilineTextAlignment(.center)

                        VStack(spacing: 12) {
                            SecurityRow(
                                icon: "passkey-new",
                                title: "Passkey",
                                subtitle: "Account is secured with Apple iCloud Passkey.",
                                subtitleColor: Color(hex: "#02542d"),
                                trailing: AnyView(
                                    Toggle("", isOn: $passkeyEnabled)
                                        .labelsHidden()
                                        .tint(Color("PrimaryNuriLilac"))
                                )
                            )

                            SecurityRow(
                                icon: "icloud-download",
                                title: "iCloud Backup",
                                subtitle: "A Passkey encrypted backup of your Key is in your iCloud.",
                                subtitleColor: Color(hex: "#02542d"),
                                trailing: AnyView(
                                    Toggle("", isOn: $iCloudBackupEnabled)
                                        .labelsHidden()
                                        .tint(Color("PrimaryNuriLilac"))
                                )
                            )

                            SecurityRow(
                                icon: "touch-id",
                                title: "Add Hardware Key",
                                subtitle: "Secure your account with a Nuri key, Yubikey, Hardware Wallet, and more.",
                                subtitleColor: Color(hex: "#6D6D86"),
                                trailing: AnyView(
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color("PrimaryNuriBlack"))
                                )
                            )
                        }
                        .padding(.horizontal, 16)

                        actionButton()
                            .padding(.top, 24)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - Components

    private func topNavigationBar() -> some View {
        HStack {
            Image("nuri-logo-svg-correct")
                .resizable()
                .frame(width: 24, height: 24)

            Spacer()

            Button(action: {
                // Add Key action
            }) {
                Text("+Add Key")
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color("PrimaryNuriBlack"))
                    .cornerRadius(64)
            }
        }
    }

    private func actionButton() -> some View {
        Button(action: {
            // Add Passkey action
        }) {
            HStack(spacing: 8) {
                Image("passkey")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 26)
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

private struct SecurityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var subtitleColor: Color = Color(hex: "#02542d")
    let trailing: AnyView

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(icon)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Inter", size: 16).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                Text(subtitle)
                    .font(.custom("Inter", size: 16).weight(.medium))
                    .foregroundColor(subtitleColor)
            }

            Spacer()

            trailing
        }
        .padding(.vertical, 12)
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