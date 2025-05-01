struct PhoneNumberViewState: ViewModelViewState {
    let title: String
    let subtitle: String
    let countryPickerTitle: String
    var countryPickerValue: String
    let countryPickerSelected: UserAction
    var countryCode: String
    var phoneNumber: TextFieldViewState
    var countryCodeHint: String?
    var confirmButton: TextButtonViewState

    static var empty: PhoneNumberViewState {
        .init(
            title: "",
            subtitle: "",
            countryPickerTitle: "",
            countryPickerValue: "",
            countryPickerSelected: .empty,
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
