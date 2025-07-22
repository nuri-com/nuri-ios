import SwiftUI

struct EmailView: View {

    @ObservedObject var viewModel: EmailViewModel

    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    @ViewBuilder
    private func contentView(viewState: EmailViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewState.title)
                .font(.brandTitle1)
                .foregroundStyle(Color.primary)
            Text(viewState.subtitle)
                .font(.brandBody)
                .foregroundStyle(Color.secondary)
            HStack(spacing: 8) {
                TextField(viewState.emailTextField.placeholder, text: $viewModel.viewState.emailTextField.text)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .onChange(of: viewState.emailTextField.text) { _, newValue in
                        viewState.emailTextField.textChangeHandler?.action(newValue)
                    }
            }
            .font(.brandCaption)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(NuriAsset.inputBackground.swiftUIColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Spacer()
            TextButton(viewState: viewState.nextButton)
                .buttonStyle(ProminentButtonStyle())
        }
        .padding(32)
        .frame(maxHeight: .infinity)
        .background(NuriAsset.background.swiftUIColor)
        .onAppear {

        }
    }
}
