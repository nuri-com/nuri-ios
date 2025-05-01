import SwiftUI

struct VerifyCallView: View {

    @ObservedObject var viewModel: VerifyCallViewModel

    var body: some View {
        contentView(viewState: viewModel.viewState)
    }

    @ViewBuilder
    private func contentView(viewState: VerifyCallViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewState.title)
                .font(.brandTitle1)
                .foregroundStyle(Color.primary)
            Text(viewState.subtitle)
                .font(.brandBody)
                .foregroundStyle(Color.secondary)
            Spacer()
            Image(viewState.illustrationName)
            Spacer()
            HStack {
                Image(systemName: "checkmark")
                Text(viewState.successMessage ?? "x")
                    .font(.brandBody)
                Spacer()
            }
            .foregroundStyle(Color.white)
            .padding(20)
            .background(Color.successGreen)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(viewState.successMessage != nil ? 1 : 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}
