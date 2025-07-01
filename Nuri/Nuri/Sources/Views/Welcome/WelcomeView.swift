import SwiftUI
import UIKit
import AuthenticationServices
import PrivySDK

struct WelcomeView: View {

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack {
                    Spacer()
                    Text("The gateway to bitcoin and new financial opportunities.")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(40)
                        .multilineTextAlignment(.center)
                    Image("intro")
                        .resizable()
                        .scaleEffect(1.1)
                        .offset(y: 20)
                }
                VStack {
                    Spacer()
                    AppleSignInButton {
                        Task { @MainActor in
                            do {
                                try await PrivyManager.shared.oAuth.login(with: .apple)
                                // Provision wallets if needed
                                do { try await WalletProvisioner.ensureWallets() } catch { print("⚠️ Wallet provisioning error", error) }
                                isUserLoggedIn = true
                            } catch {
                                print("❌ Apple sign-in failed:", error)
                            }
                        }
                    }
                    .frame(height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Sign In with Passkey") {
                        PasskeyAuthCoordinator.shared.start { result in
                            switch result {
                            case .success:
                                DispatchQueue.main.async { isUserLoggedIn = true }
                            case .failure(let error):
                                print("❌ Passkey sign-in failed:", error)
                            }
                        }
                    }
                    .buttonStyle(ProminentButtonStyle())

                    Button("Create Passkey") {
                        PasskeyAuthCoordinator.shared.register { result in
                            switch result {
                            case .success:
                                DispatchQueue.main.async { isUserLoggedIn = true }
                            case .failure(let error):
                                print("❌ Passkey registration failed:", error)
                            }
                        }
                    }
                    .buttonStyle(ProminentButtonStyle())

                    Button("Skip Login") {
                        isUserLoggedIn = true
                    }
                    .buttonStyle(ProminentButtonStyle())
                }
                .padding(32)
            }
            .background(NuriAsset.brandOrange.swiftUIColor)
        }
    }
}

#Preview {
    WelcomeView()
}

// MARK: - Apple Sign-In SwiftUI wrapper
private struct AppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}
