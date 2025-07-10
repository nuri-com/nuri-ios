import SwiftUI
import AuthenticationServices

struct LoginView: View {

    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    @ViewBuilder
    private func contentView(viewState: LoginViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewState.title)
                .font(.brandTitle1)
                .foregroundStyle(Color.primary)
            Text(viewState.subtitle)
                .font(.brandBody)
                .foregroundStyle(Color.secondary)
            Spacer()
            TextField(viewState.emailTextField.placeholder, text: $viewModel.viewState.emailTextField.text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    viewState.emailTextField.submitHandler?.action()
                }
            AppleSignInButton(action: viewState.appleLoginAction.action)
                .frame(height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            TextButton(viewState: viewState.authButton)
            .buttonStyle(ProminentButtonStyle())
            Spacer()
        }
        .padding(32)
        .frame(maxHeight: .infinity)
        .background(NuriAsset.background.swiftUIColor)
    }
}

// SwiftUI wrapper for the native ASAuthorizationAppleIDButton so we get the official style.
private struct AppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    class Coordinator {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}
