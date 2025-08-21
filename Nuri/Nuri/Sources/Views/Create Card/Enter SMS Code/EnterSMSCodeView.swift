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
        .loadingOverlay(
            isPresented: viewModel.viewState.isLoadingAnimationActive,
            title: "Verifying code...",
            subtitle: nil
        )
        // REMOVED: Navigation to UserInfoView
        // After KYC approval, PostKYCCoordinator handles the flow
        // This prevents SMS screen from appearing again
    }
}
