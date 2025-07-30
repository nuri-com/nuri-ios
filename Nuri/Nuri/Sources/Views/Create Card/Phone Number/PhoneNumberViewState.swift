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
    var showCountryPicker: Bool
    let countryPickedAction: UserObjectAction<SearchCountryDialCodeResult>
    var showEmailScreen: Bool

    static var empty: PhoneNumberViewState {
        .init(
            title: "",
            subtitle: "",
            countryPickerTitle: "",
            countryPickerValue: "",
            countryPickerSelected: .empty,
            countryCode: "",
            phoneNumber: .empty,
            confirmButton: .empty,
            showCountryPicker: false,
            countryPickedAction: .empty,
            showEmailScreen: false
        )
    }
}

extension PhoneNumberViewState {

    enum Action: Equatable {
        case selectCountry(Int)
        case updatePhoneNumber(String)
        case showCountryPicker(Bool)
        case showEmailScreen
    }
}
