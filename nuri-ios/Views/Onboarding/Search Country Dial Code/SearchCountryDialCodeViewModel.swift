import Combine

protocol SearchCountryDialCodeViewModelDelegate: AnyObject {
    func searchCancelled()
    func didSelectCountry(countryCode: String)
}

protocol SearchCountryDialCodeViewModelType: AnyObject {
    func toViewModel() -> SearchCountryDialCodeViewModel
    var delegate: SearchCountryDialCodeViewModelDelegate? { get set }
}

protocol SearchCountryDialCodeViewStateProviding {
    var viewState: SearchCountryDialCodeViewState { get }
}

final class SearchCountryDialCodeViewModel: ObservableObject, SearchCountryDialCodeViewModelType {

    private let searchCountryDialCodeUseCase: SearchCountryDialCodeUseCaseType

    weak var delegate: SearchCountryDialCodeViewModelDelegate?

    @Published var viewState: SearchCountryDialCodeViewState = .empty

    init(searchCountryDialCodeUseCase: SearchCountryDialCodeUseCaseType) {
        self.searchCountryDialCodeUseCase = searchCountryDialCodeUseCase

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
        delegate?.searchCancelled()
    }

    private func selectionHandler(_ countryCode: String) {
        delegate?.didSelectCountry(countryCode: countryCode)
    }

    func toViewModel() -> SearchCountryDialCodeViewModel {
        return self
    }
}

private extension SearchCountryDialCodeViewState.ResultItem {

    init(countryDialCode: CountryDialCode) {
        id = countryDialCode.countryCode
        flag = countryDialCode.countryCode
        text = [countryDialCode.dialCode, countryDialCode.country].joined(separator: " ")
    }
}
