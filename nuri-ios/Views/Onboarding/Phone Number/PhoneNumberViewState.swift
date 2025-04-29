struct PhoneNumberViewState: ViewModelViewState {
    let title: String
    let subtitle: String
    var countryPicker: PickerViewState
    var countryCode: String
    var phoneNumber: TextFieldViewState
    var countryCodeHint: String?
    var confirmButton: TextButtonViewState

    static var empty: PhoneNumberViewState {
        .init(
            title: "",
            subtitle: "",
            countryPicker: .empty,
            countryCode: "",
            phoneNumber: .empty,
            confirmButton: .empty
        )
    }
}

extension PhoneNumberViewState {

    enum Action: Equatable {
        case selectCountry(Int)
        case updatePhoneNumber(String)
    }
}
