import SwiftUI

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
            Text(viewState.orLabel)
            TextButton(viewState: viewState.passkeyButton)
            .buttonStyle(ProminentButtonStyle())
            Spacer()
        }
        .padding(32)
        .frame(maxHeight: .infinity)
        .background(NuriAsset.background.swiftUIColor)
    }
}
