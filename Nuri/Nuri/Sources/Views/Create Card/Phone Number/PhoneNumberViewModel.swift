import Combine
import StrigaAPI
import Foundation

final class PhoneNumberViewModel: ObservableObject {

    // MARK: - Dependencies

    private let dialCodesRepository: CountryDialCodesRepositoryType = CountryDialCodesRepository()
    var striga = StrigaService.shared

    // MARK: - Variables

    @Published var viewState: PhoneNumberViewState = .empty

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
            },
            showEmailScreen: false,
            isCreatingUser: false
        )

        updateViewState(action: .selectCountry(78))
        
        // Configure Striga if not already configured
        if striga.configuration == nil {
            striga.configuration = StrigaConfiguration(
                url: "https://www.sandbox.striga.com/api/",
                key: "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=",
                secret: "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE="
            )
            print("[PhoneNumber] Configured Striga for sandbox environment")
        }
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
            print("index \(index)")
            let dialCode = country.dialCode
            viewState.countryCode = dialCode
            viewState.countryPickerValue = country.country

            countries.remove(at: index)
            let otherCountries = countries.filter({ $0.dialCode == dialCode }).map { $0.country }.sorted()
            if otherCountries.isEmpty == false {
                viewState.countryCodeHint = dialCode + " is also the dial code for:\n" + otherCountries.map({ "- \($0)" }).joined(separator: "\n")
            } else {
                viewState.countryCodeHint = nil
            }
            // Validate phone number
            let phoneNumber = viewState.phoneNumber.text
            let isValid = isValidPhoneNumber(phoneNumber)
            viewState.confirmButton.isDisabled = !isValid
        case .updatePhoneNumber(let phoneNumber):
            viewState.phoneNumber.text = phoneNumber
            // Validate phone number
            let isValid = isValidPhoneNumber(phoneNumber)
            viewState.confirmButton.isDisabled = !isValid
        case .showCountryPicker(let showCountryPicker):
            viewState.showCountryPicker = showCountryPicker
        case .showEmailScreen:
            viewState.showEmailScreen = true
        case .setLoading(let isLoading):
            viewState.isCreatingUser = isLoading
        }
        return viewState
    }

    private func confirmButtonPressed() {
        // Store phone number data in session
        // Keep the + in country code as Striga expects it
        StrigaSession.shared.phoneNumber = viewState.phoneNumber.text
        StrigaSession.shared.phoneCountryCode = viewState.countryCode // Keep the + prefix
        
        print("[PhoneNumber] Storing phone data:")
        print("  - Country Code: \(viewState.countryCode)")
        print("  - Phone Number: \(viewState.phoneNumber.text)")
        
        // CRITICAL: We need to create the user HERE, before SMS screen
        // This will trigger Striga to send the SMS
        Task {
            await createUserAndNavigateToSMS()
        }
    }
    
    @MainActor
    private func createUserAndNavigateToSMS() async {
        // Show loading state
        viewState.isCreatingUser = true
        
        // Create the user NOW (this triggers SMS from Striga)
        do {
            // Get all collected data from StrigaSession
            guard let email = StrigaSession.shared.email,
                  let firstName = StrigaSession.shared.firstName,
                  let lastName = StrigaSession.shared.lastName,
                  let address = StrigaSession.shared.address,
                  let dateOfBirth = StrigaSession.shared.dateOfBirth else {
                print("[PhoneNumber] CRITICAL ERROR: Missing required user data:")
                print("  - Email: \(StrigaSession.shared.email ?? "nil")")
                print("  - First Name: \(StrigaSession.shared.firstName ?? "nil")")
                print("  - Last Name: \(StrigaSession.shared.lastName ?? "nil")")
                print("  - Address: \(StrigaSession.shared.address != nil ? "present" : "nil")")
                print("  - Phone Number: \(viewState.phoneNumber.text)")
                print("  - Phone Country Code: \(viewState.countryCode)")
                print("  - Date of Birth: \(StrigaSession.shared.dateOfBirth != nil ? "present" : "nil")")
                
                viewState.isCreatingUser = false
                // TODO: Show error to user
                return
            }
            
            // Extra validation to ensure names are not empty
            guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("[PhoneNumber] CRITICAL ERROR: firstName or lastName is empty!")
                print("  - First Name: '\(firstName)'")
                print("  - Last Name: '\(lastName)'")
                viewState.isCreatingUser = false
                return
            }
            
            // Clean up phone number - remove leading zero if present
            var cleanedPhoneNumber = viewState.phoneNumber.text
            if cleanedPhoneNumber.hasPrefix("0") && viewState.countryCode.count > 1 {
                cleanedPhoneNumber = String(cleanedPhoneNumber.dropFirst())
            }
            
            print("[PhoneNumber] Creating Striga user with data:")
            print("  - First Name: \(firstName)")
            print("  - Last Name: \(lastName)")
            print("  - Email: \(email)")
            print("  - Phone: \(viewState.countryCode) \(cleanedPhoneNumber)")
            
            let input = CreateUser(
                firstName: firstName,
                lastName: lastName,
                email: email,
                mobile: .init(
                    countryCode: viewState.countryCode,
                    number: cleanedPhoneNumber
                ),
                address: CreateUser.Address(
                    addressLine1: address.addressLine1,
                    city: address.city,
                    country: address.country,
                    postalCode: address.postalCode
                ),
                dateOfBirth: CreateUser.Date(
                    year: dateOfBirth.year,
                    month: dateOfBirth.month,
                    day: dateOfBirth.day
                )
            )
            
            // CRITICAL: Log the exact data being sent
            print("[PhoneNumber] CRITICAL CHECK - About to create user with:")
            print("  - firstName: '\(input.firstName)' (length: \(input.firstName.count))")
            print("  - lastName: '\(input.lastName)' (length: \(input.lastName.count))")
            print("  - email: '\(input.email)'")
            
            let userResponse = try await striga.createUser(input)
            StrigaSession.shared.userId = userResponse.userId
            
            print("[PhoneNumber] User creation successful!")
            print("  - userId: \(userResponse.userId)")
            print("  - KYC Status: \(userResponse.KYC.status)")
            
            // Update passkey data with Striga user ID if user has a passkey
            if let passkeyUsername = UserDefaults.standard.string(forKey: "passkeyUsername") {
                print("[PhoneNumber] Updating passkey data with Striga user ID")
                do {
                    try await PasskeyAuthenticationService.shared.updateStrigaUserId(
                        for: passkeyUsername,
                        strigaUserId: userResponse.userId
                    )
                } catch {
                    print("[PhoneNumber] Failed to update passkey data: \(error)")
                    // Don't fail the flow if passkey update fails
                }
            }
            
            // Hide loading and navigate to SMS screen
            viewState.isCreatingUser = false
            updateViewState(action: .showEmailScreen)
            
        } catch {
            print("[PhoneNumber] Error creating user: \(error)")
            viewState.isCreatingUser = false
            
            if let validationError = error as? ValidationErrorResponse {
                print("[PhoneNumber] Validation error: \(validationError.message)")
                print("[PhoneNumber] Error code: \(validationError.errorCode)")
                print("[PhoneNumber] Error details: \(validationError.errorDetails)")
                
                if validationError.message.contains("already exists") {
                    print("[PhoneNumber] User already exists with this email/phone")
                    // For existing users, we still need to navigate to SMS screen
                    // because they need to verify their phone number
                    updateViewState(action: .showEmailScreen)
                }
            }
        }
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
        // Limit phone number to reasonable length (max 15 digits for international standards)
        let truncatedPhoneNumber = String(phoneNumber.prefix(15))
        updateViewState(action: .updatePhoneNumber(truncatedPhoneNumber))
    }
    
    private func isValidPhoneNumber(_ number: String) -> Bool {
        // Phone numbers internationally can vary from 7 to 15 digits
        // We'll be flexible and allow numbers within this range
        return number.count >= 7 && number.count <= 15 && number.allSatisfy { $0.isNumber }
    }

    // MARK: - PhoneNumberViewModelType

    func updateSelectedCountry(countryCode: String) {
        if let index = dialCodesRepository.dialCodes.firstIndex(where: { $0.countryCode == countryCode }) {
            updateViewState(action: .selectCountry(index))
        }
    }
}
