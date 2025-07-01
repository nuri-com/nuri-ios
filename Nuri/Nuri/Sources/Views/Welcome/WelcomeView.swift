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
                    
                    Button("Sign-in or Create Passkey") {
                        print("👆 [WelcomeView] User tapped 'Sign-in or Create Passkey'")
                        PasskeyAuthCoordinator.shared.signInOrRegister { result in
                            switch result {
                            case .success:
                                print("✅ [WelcomeView] Sign-in or register successful, setting isUserLoggedIn = true")
                                DispatchQueue.main.async { isUserLoggedIn = true }
                            case .failure(let error):
                                print("❌ [WelcomeView] Sign-in or register failed:", error)
                            }
                        }
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
