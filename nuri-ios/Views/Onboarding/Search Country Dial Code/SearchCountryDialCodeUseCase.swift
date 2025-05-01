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
        var result: [CountryDialCode] = countryDialCodesRepository.dialCodes
        if !searchText.isEmpty {
            result = result.filter { countryDialCode in
                countryDialCode.country.lowercased().contains(searchText) || countryDialCode.dialCode.contains(text)
            }
        }
        return result.sorted { $0.country < $1.country }
    }
}
