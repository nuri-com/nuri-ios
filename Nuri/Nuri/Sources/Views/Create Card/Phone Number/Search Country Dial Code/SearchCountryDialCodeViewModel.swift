import Combine

enum SearchCountryDialCodeResult {
    case cancelled
    case country(countryCode: String)
}

protocol SearchCountryDialCodeViewStateProviding {
    var viewState: SearchCountryDialCodeViewState { get }
}

final class SearchCountryDialCodeViewModel: ObservableObject {

    // MARK: - Dependencies

    private let searchCountryDialCodeUseCase = SearchCountryDialCodeUseCase()

    // MARK: - Variables

    var completion: ((SearchCountryDialCodeResult) -> Void)?

    // MARK: - View State

    @Published var viewState: SearchCountryDialCodeViewState = .empty

    // MARK: - Initialization

    init() {
        self.viewState = .init(
            searchTextField: .init(
                label: "",
                text: "",
                placeholder: "Country name or dial code",
                textChangeHandler: .init { [weak self] searchText in
                    self?.handleSearchTextChange(searchText)
                }
            ),
            cancelButton: .init(
                text: "Cancel",
                action: .init { [weak self] in
                    self?.cancelButtonPressed()
                }
            ),
            searchState: searchState(for: "")
        )
    }

    // MARK: - Private

    private func handleSearchTextChange(_ searchText: String) {
        viewState.searchState = searchState(for: searchText)
    }

    private func searchState(for searchText: String) -> SearchCountryDialCodeViewState.SearchState {
        let searchState: SearchCountryDialCodeViewState.SearchState
        let countryDialCodes = searchCountryDialCodeUseCase.search(text: searchText)
        if countryDialCodes.isEmpty {
            searchState = .noResults("No matches found.")
        } else {
            searchState = .results(.init(
                items: countryDialCodes.map { .init(countryDialCode: $0) },
                selectionHandler: .init { [weak self] countryCode in
                    self?.selectionHandler(countryCode)
                }
            ))
        }
        return searchState
    }

    private func cancelButtonPressed() {
        completion?(.cancelled)
    }

    private func selectionHandler(_ countryCode: String) {
        completion?(.country(countryCode: countryCode))
    }
}

private extension SearchCountryDialCodeViewState.ResultItem {

    init(countryDialCode: CountryDialCode) {
        id = countryDialCode.countryCode
        flag = countryDialCode.countryCode
        text = [countryDialCode.dialCode, countryDialCode.country].joined(separator: " ")
    }
}
