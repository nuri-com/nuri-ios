import SwiftUI

struct PhoneNumberView: View {

    @ObservedObject var viewModel: PhoneNumberViewModel

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
                Text(viewState.countryPicker.label)
                    .font(.brandCaption)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Picker(viewState.countryPicker.label, selection: $viewModel.viewState.countryPicker.selection) {
                    ForEach(Array(viewState.countryPicker.options.enumerated()), id: \.element) { index, element in
                        Text(element)
                            .fixedSize(horizontal: true, vertical: false)
                            .truncationMode(.tail)
                            .tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .tint(Color.primary)
                .onChange(of: viewState.countryPicker.selection) { _, newValue in
                    viewState.countryPicker.selectionChangeHandler?.action(newValue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(.vertical, 8)
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
            .background(Color.inputBackground)
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
        .background(Color.background)
    }
}
