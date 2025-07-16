final class SearchCountryDialCodeUseCase {

    // MARK: - Dependencies

    private let countryDialCodesRepository: CountryDialCodesRepositoryType

    // MARK: - Initialization

    init(countryDialCodesRepository: CountryDialCodesRepositoryType = CountryDialCodesRepository()) {
        self.countryDialCodesRepository = countryDialCodesRepository
    }

    // MARK: - Use Case

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
