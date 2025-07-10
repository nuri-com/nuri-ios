import SwiftUI
import UIKit
import AuthenticationServices
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
                    
                    Button("Get Started") {
                        continueToApp()
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
    
    private func continueToApp() {
        print("👆 [WelcomeView] User tapped 'Get Started'")
        print("✅ [WelcomeView] Continuing to app - wallet should already be initialized")
        
        // Wallet should already be initialized by NuriApp.init()
        self.isUserLoggedIn = true
        self.dismiss()
    }
    
    private func skipForNow() {
        print("⏩ [WelcomeView] User skipped authentication setup")
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
