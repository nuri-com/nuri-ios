import SwiftUI

struct SearchCountryDialCodeView: View {

    @ObservedObject var viewModel: SearchCountryDialCodeViewModel


    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    @ViewBuilder
    private func contentView(viewState: SearchCountryDialCodeViewState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField(viewState.searchTextField.placeholder, text: $viewModel.viewState.searchTextField.text)
                    .onChange(of: viewState.searchTextField.text) { _, newValue in
                        viewState.searchTextField.textChangeHandler?.action(newValue)
                    }
                TextButton(viewState: viewState.cancelButton)
            }
            .padding(32)
            switch viewState.searchState {
            case .noResults(let text):
                HStack {
                    Spacer()
                    Text(text)
                        .font(.brandBody)
                        .foregroundStyle(Color.secondary)
                        .padding(32)
                    Spacer()
                }
                Spacer()
            case .results(let resultViewState):
                List(resultViewState.items) { item in
                    HStack {
                        Text(item.flag)
                            .frame(width: 30)
                        Text(item.text)
                            .lineLimit(1, reservesSpace: false)
                            .truncationMode(.tail)
                    }
                    .tag(item.id)
                    .onTapGesture {
                        resultViewState.selectionHandler.action(item.id)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}
