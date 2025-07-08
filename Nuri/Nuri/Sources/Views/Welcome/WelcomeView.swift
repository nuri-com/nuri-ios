import SwiftUI
import UIKit
import AuthenticationServices
import PrivySDK
import BitcoinDevKit

struct WelcomeView: View {

    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack {
                    Spacer()
                    Text("Your Biometrics. Your Bitcoin. Your Money.")
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
                    
                    Button("Login with Biometrics") {
                        signInOrCreatePasskey()
                    }
                    .buttonStyle(ProminentButtonStyle())
                }
                .padding(32)
            }
            .background(NuriAsset.brandOrange.swiftUIColor)
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions
    
    private func signInOrCreatePasskey() {
        print("👆 [WelcomeView] User tapped 'Sign-in or Create Passkey'")
        PasskeyAuthCoordinator.shared.signInOrRegister { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ [WelcomeView] Passkey operation successful")
                    
                    // Get stored tokens and initialize wallet for user
                    let tokens = PasskeyService.getStoredTokens()
                    print("📦 [WelcomeView] Stored tokens - Access: \(tokens.0?.prefix(20) ?? "nil")... User: \(tokens.2 ?? "nil")")
                    
                    // Initialize Bitcoin wallet for this specific user
                    if let userID = tokens.2 {
                        print("🔑 [WelcomeView] Initializing wallet for user: \(userID)")
                        BitcoinWalletService.shared.initializeForUser(userID)
                    } else {
                        print("⚠️ [WelcomeView] No user ID found in tokens")
                    }
                    
                    self.isUserLoggedIn = true
                    self.dismiss()
                case .failure(let error):
                    print("❌ [WelcomeView] Passkey operation failed: \(error)")
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    private func skipForNow() {
        print("⏩ [WelcomeView] User skipped passkey setup")
        dismiss()
    }
    
    // MARK: - View Helpers
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
