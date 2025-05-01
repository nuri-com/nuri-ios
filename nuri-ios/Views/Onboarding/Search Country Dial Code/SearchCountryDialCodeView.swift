import SwiftUI

struct SearchCountryDialCodeView: View {

    @ObservedObject var viewModel: SearchCountryDialCodeViewModel


    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    @ViewBuilder
    private func contentView(viewState: SearchCountryDialCodeViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(viewState.searchTextField.placeholder, text: $viewModel.viewState.searchTextField.text)
                TextButton(viewState: viewState.cancelButton)
            }
            switch viewState.searchState {
            case .noResults(let text):
                Text(text)
            case .results(let resultViewState):
                List(resultViewState.items) { item in
                    HStack {
                        Text(item.flag)
                        Text(item.text)
                    }
                    .tag(item.id)
                    .onTapGesture {
                        resultViewState.selectionHandler.action(item.id)
                    }
                }
            }
        }
        .padding(32)
        .frame(maxHeight: .infinity)
        .background(Color.background)
    }
}
