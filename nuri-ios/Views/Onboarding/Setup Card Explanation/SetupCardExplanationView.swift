import SwiftUI

struct SetupCardExplanationView: View {

    @ObservedObject var viewModel: SetupCardExplanationViewModel

    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    private let padding: CGFloat = 32

    @ViewBuilder
    private func contentView(viewState: SetupCardExplanationViewState) -> some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewState.title)
                        .font(.brandTitle1)
                        .foregroundStyle(Color.textPrimary)
                    Text(LocalizedStringKey(viewState.subtitle))
                        .font(.brandBody)
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(padding)
                Spacer()
                Image(viewState.illustrationName)
                    .resizable()
//                    .frame(width: geometry.size.width)
                Spacer()
                TextButton(viewState: viewState.continueButton)
                    .buttonStyle(ProminentBlackButtonStyle())
                    .padding(padding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.accentColor)
        }
    }

}
