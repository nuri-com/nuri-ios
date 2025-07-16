import Combine

final class PhoneNumberViewModel: ObservableObject {

    // MARK: - Dependencies

    private let dialCodesRepository: CountryDialCodesRepositoryType = CountryDialCodesRepository()

    // MARK: - Variables

    @Published var viewState: PhoneNumberViewState = .empty
    var completion: (() -> Void)? = nil

    // MARK: - Initialization

    init() {
        viewState = .init(
            title: "Your Phone Number",
            subtitle: "Enter your phone number to get started.",
            countryPickerTitle: "Country",
            countryPickerValue: "",
            countryPickerSelected: .init { [weak self] in
                self?.countryPickerSelected()
            },
            countryCode: "+",
            phoneNumber: .init(
                label: "",
                text: "",
                placeholder: "Your phone number",
                textChangeHandler: .init { [weak self] text in
                    self?.phoneNumberChanged(text)
                }
            ),
            confirmButton: .init(
                text: "Confirm",
                action: { [weak self] in
                    self?.confirmButtonPressed()
                },
                isDisabled: true
            ),
            showCountryPicker: false,
            countryPickedAction: .init { [weak self] result in
                switch result {
                case .cancelled: break
                case .country(countryCode: let countryCode):
                    self?.updateSelectedCountry(countryCode: countryCode)
                }
                self?.updateViewState(action: .showCountryPicker(false))
            }
        )

        updateViewState(action: .selectCountry(0))
    }

    // MARK: - Private

    private func updateViewState(action: PhoneNumberViewState.Action) {
        viewState = reduce(viewState, action: action)
    }

    private func reduce(_ viewState: PhoneNumberViewState, action: PhoneNumberViewState.Action) -> PhoneNumberViewState {
        var viewState = viewState
        switch action {
        case .selectCountry(let index):
            var countries = dialCodesRepository.dialCodes
            let country = countries[index]
            let dialCode = country.dialCode
            viewState.countryCode = dialCode
            viewState.countryPickerValue = country.dialCode + " " + country.country

            countries.remove(at: index)
            let otherCountries = countries.filter({ $0.dialCode == dialCode }).map { $0.country }.sorted()
            if otherCountries.isEmpty == false {
                viewState.countryCodeHint = dialCode + " is also the dial code for:\n" + otherCountries.map({ "- \($0)" }).joined(separator: "\n")
            } else {
                viewState.countryCodeHint = nil
            }
        case .updatePhoneNumber(let phoneNumber):
            viewState.phoneNumber.text = phoneNumber
            viewState.confirmButton.isDisabled = phoneNumber.count < 5
        case .showCountryPicker(let showCountryPicker):
            viewState.showCountryPicker = showCountryPicker
        }
        return viewState
    }

    private func confirmButtonPressed() {
        completion?()
    }

    private func countryPickerSelectionChanged(_ selection: Int) {
        updateViewState(action: .selectCountry(selection))
    }

    private func countryPickerSelected() {
        updateViewState(action: .showCountryPicker(true))
    }

    private func phoneNumberChanged(_ text: String) {
        let trimmedText = text.replacing(" ", with: "")
        let regex = /^\+[0-9]{1,4}/
        if (try? regex.firstMatch(in: trimmedText)) != nil {
            let allDialCodes = dialCodesRepository.dialCodes
            let sortedDialCodesNumber = allDialCodes.map { $0.dialCode }.sorted(by: { $0.count > $1.count })
            for dialCodeNumber in sortedDialCodesNumber {
                if trimmedText.starts(with: dialCodeNumber) {
                    if let dialCode = allDialCodes.first(where: { $0.dialCode == dialCodeNumber }) {
                        if let index = dialCodesRepository.dialCodes.firstIndex(of: dialCode) {
                            updateViewState(action: .selectCountry(index))
                            let phoneNumber = trimmedText.replacingOccurrences(of: dialCodeNumber, with: "")
                            updatePhoneNumberIfValid(phoneNumber)
                            break
                        }
                    }
                }
            }
        } else {
            updatePhoneNumberIfValid(trimmedText)
        }
    }

    private func updatePhoneNumberIfValid(_ phoneNumber: String) {
        let phoneNumber = phoneNumber.filter { $0.isNumber }
        updateViewState(action: .updatePhoneNumber(phoneNumber))
    }

    // MARK: - PhoneNumberViewModelType

    func updateSelectedCountry(countryCode: String) {
        if let index = dialCodesRepository.dialCodes.firstIndex(where: { $0.countryCode == countryCode }) {
            updateViewState(action: .selectCountry(index))
        }
    }
}
