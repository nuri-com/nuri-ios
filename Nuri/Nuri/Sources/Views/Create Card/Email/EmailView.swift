import SwiftUI

struct EmailView: View {

    @ObservedObject var viewModel: EmailViewModel

    var body: some View {
        UnifiedInputView(
            mode: .email,
            inputText: $viewModel.viewState.emailTextField.text,
            countryCode: .constant(""),
            showCountryPicker: .constant(false),
            countryName: "",
            isValid: !viewModel.viewState.isLoading && !viewModel.viewState.emailTextField.text.isEmpty,
            onNext: {
                viewModel.viewState.nextButton.action.action()
            },
            onCountryPicked: { _ in }
        )
        .onChange(of: viewModel.viewState.emailTextField.text) { _, newValue in
            viewModel.viewState.emailTextField.textChangeHandler?.action(newValue)
        }
        .navigationDestination(isPresented: $viewModel.viewState.showSMSView) {
            EnterSMSCodeView()
        }
    }
}
