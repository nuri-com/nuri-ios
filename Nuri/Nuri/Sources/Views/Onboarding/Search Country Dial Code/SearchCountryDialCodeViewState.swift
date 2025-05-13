struct SearchCountryDialCodeViewState: ViewModelViewState {
    var searchTextField: TextFieldViewState
    let cancelButton: TextButtonViewState
    var searchState: SearchState

    static var empty: SearchCountryDialCodeViewState {
        .init(searchTextField: .empty, cancelButton: .empty, searchState: .noResults(""))
    }
}

extension SearchCountryDialCodeViewState {

    enum SearchState: Equatable {
        case noResults(String)
        case results(ResultViewState)
    }

    struct ResultViewState: Equatable {
        let items: [ResultItem]
        let selectionHandler: UserObjectAction<ResultItem.ID>
    }

    struct ResultItem: ViewModelViewState, Identifiable {
        let id: String
        let flag: String
        let text: String

        static var empty: ResultItem {
            .init(id: "", flag: "", text: "")
        }
    }
}
