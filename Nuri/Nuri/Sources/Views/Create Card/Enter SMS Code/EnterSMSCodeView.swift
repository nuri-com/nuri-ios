import SwiftUI

struct EnterSMSCodeView: View {

    @ObservedObject var viewModel = EnterSMSCodeViewModel()
    @EnvironmentObject var navigation: CreateCardNavigation

    var body: some View {
        UnifiedInputView(
            mode: .smsCode,
            inputText: $viewModel.viewState.codeTextField.text,
            countryCode: .constant(""),
            showCountryPicker: .constant(false),
            countryName: "",
            isValid: !viewModel.viewState.codeTextField.text.isEmpty && viewModel.viewState.codeTextField.text.count == 6,
            onNext: {
                // Auto-submits when 6 digits are entered
            },
            onCountryPicked: { _ in }
        )
        .onChange(of: viewModel.viewState.codeTextField.text) { _, newValue in
            viewModel.viewState.codeTextField.textChangeHandler?.action(newValue)
        }
        // Card creation now happens automatically in background after KYC approval
        .loadingOverlay(
            isPresented: viewModel.viewState.isLoadingAnimationActive,
            title: "Verifying code...",
            subtitle: nil
        )
        // Card creation now happens automatically in background after KYC approval
    }
}
