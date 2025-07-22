import SwiftUI

struct EnterSMSCodeView: View {

    @ObservedObject var viewModel = EnterSMSCodeViewModel()

    init(completion: @escaping () -> Void) {
        viewModel.completion = completion
    }

    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    @ViewBuilder
    private func contentView(viewState: EnterSMSCodeViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewState.title)
                .font(.brandTitle1)
                .foregroundStyle(NuriAsset.textPrimary.swiftUIColor)
            Text(viewState.subtitle)
                .font(.brandBody)
                .foregroundStyle(NuriAsset.textSecondary.swiftUIColor)
            Spacer()
            Image(viewState.illustrationName)
            Spacer()
            HStack(spacing: 8) {
                Text(viewState.codeTextField.placeholder)
                TextField(viewState.codeTextField.placeholder, text: $viewModel.viewState.codeTextField.text)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: viewState.codeTextField.text) { _, newValue in
                        viewState.codeTextField.textChangeHandler?.action(newValue)
                    }
            }
            .font(.brandCaption)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(NuriAsset.inputBackground.swiftUIColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NuriAsset.background.swiftUIColor)
    }
}
