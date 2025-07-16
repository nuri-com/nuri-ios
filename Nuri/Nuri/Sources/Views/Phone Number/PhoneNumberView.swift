import SwiftUI

struct PhoneNumberView: View {

    @ObservedObject var viewModel = PhoneNumberViewModel()

    init(completion: (() -> Void)? = nil) {
        viewModel.completion = completion
    }

    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    @ViewBuilder
    private func contentView(viewState: PhoneNumberViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewState.title)
                .font(.brandTitle1)
                .foregroundStyle(Color.primary)
            Text(viewState.subtitle)
                .font(.brandBody)
                .foregroundStyle(Color.secondary)
            HStack {
                Text(viewState.countryPickerTitle)
                    .font(.brandCaption)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text(viewState.countryPickerValue)
                    .font(.brandBody)
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(NuriAsset.inputBackground.swiftUIColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(.vertical, 8)
            .onTapGesture {
                viewState.countryPickerSelected.action()
            }
            HStack(spacing: 8) {
                Text(viewState.countryCode)
                TextField(viewState.phoneNumber.placeholder, text: $viewModel.viewState.phoneNumber.text)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .onChange(of: viewState.phoneNumber.text) { _, newValue in
                        viewState.phoneNumber.textChangeHandler?.action(newValue)
                    }
            }
            .font(.brandCaption)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(NuriAsset.inputBackground.swiftUIColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            if let countryCodeHint = viewState.countryCodeHint {
                Text(countryCodeHint)
                    .font(.brandBody)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            TextButton(viewState: viewState.confirmButton)
                .buttonStyle(ProminentButtonStyle())
        }
        .padding(32)
        .frame(maxHeight: .infinity)
        .background(NuriAsset.background.swiftUIColor)
        .sheet(isPresented: $viewModel.viewState.showCountryPicker) {
            SearchCountryDialCodeView() { result in
                viewState.countryPickedAction.action(result)
            }
        }
        .navigationDestination(isPresented: $viewModel.viewState.showVerifyScreen) {
            VerifyCallView() {
                
            }
        }
    }
}
