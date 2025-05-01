import Combine

protocol PhoneNumberViewModelDelegate: OnboardingScreenDelegate {
    func phoneNumberViewModelDidSelectSearch()
}

protocol PhoneNumberViewModelType: AnyObject {
    var delegate: PhoneNumberViewModelDelegate? { get set }
    func updateSelectedCountry(countryCode: String)
    func toViewModel() -> PhoneNumberViewModel
}

protocol PhoneNumberViewStateProviding {
    var viewState: PhoneNumberViewState { get }
}

final class PhoneNumberViewModel: ObservableObject, PhoneNumberViewModelType, PhoneNumberViewStateProviding {

    weak var delegate: (any PhoneNumberViewModelDelegate)?

    @Published var viewState: PhoneNumberViewState = .empty

    private let dialCodesRepository: CountryDialCodesRepositoryType

    init(dialCodesRepository: CountryDialCodesRepositoryType) {
        self.dialCodesRepository = dialCodesRepository

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
            )
        )

        updateViewState(action: .selectCountry(0))
    }

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
        }
        return viewState
    }

    private func confirmButtonPressed() {
        delegate?.didFinish(screen: .phoneNumber)
    }

    private func countryPickerSelectionChanged(_ selection: Int) {
        updateViewState(action: .selectCountry(selection))
    }

    private func countryPickerSelected() {
        delegate?.phoneNumberViewModelDidSelectSearch()
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

    func toViewModel() -> PhoneNumberViewModel {
        return self
    }
}
