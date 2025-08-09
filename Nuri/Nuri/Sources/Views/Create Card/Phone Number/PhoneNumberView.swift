import SwiftUI

struct PhoneNumberView: View {

    @ObservedObject var viewModel = PhoneNumberViewModel()

    var body: some View {
        ZStack {
            UnifiedInputView(
                mode: .phone,
                inputText: $viewModel.viewState.phoneNumber.text,
                countryCode: $viewModel.viewState.countryCode,
                showCountryPicker: $viewModel.viewState.showCountryPicker,
                countryName: viewModel.viewState.countryPickerValue,
                isValid: !viewModel.viewState.confirmButton.isDisabled,
                onNext: {
                    viewModel.viewState.confirmButton.action.action()
                },
                onCountryPicked: { result in
                    viewModel.viewState.countryPickedAction.action(result)
                }
            )
            .onChange(of: viewModel.viewState.phoneNumber.text) { _, newValue in
                viewModel.viewState.phoneNumber.textChangeHandler?.action(newValue)
            }
            .navigationDestination(isPresented: $viewModel.viewState.showEmailScreen) {
                EnterSMSCodeView()
            }
            
            if viewModel.viewState.isCreatingUser {
                LoadingOverlay(title: "Creating your account...", subtitle: nil)
            }
        }
    }
}
