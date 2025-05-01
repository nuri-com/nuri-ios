protocol SearchCountryDialCodeUseCaseType {
    func search(text: String) -> [CountryDialCode]
}

final class SearchCountryDialCodeUseCase: SearchCountryDialCodeUseCaseType {

    private let countryDialCodesRepository: CountryDialCodesRepositoryType

    init(countryDialCodesRepository: CountryDialCodesRepositoryType) {
        self.countryDialCodesRepository = countryDialCodesRepository
    }

    func search(text: String) -> [CountryDialCode] {
        let searchText = text.trimmingCharacters(in: .whitespaces).lowercased()
        return countryDialCodesRepository.dialCodes.filter { countryDialCode in
            countryDialCode.country.lowercased().contains(searchText) || countryDialCode.dialCode.contains(text)
        }
    }
}
