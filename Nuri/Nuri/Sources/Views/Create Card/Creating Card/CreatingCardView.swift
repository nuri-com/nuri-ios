import SwiftUI

struct CreatingCardView: View {

    @ObservedObject var viewModel = CreatingCardViewModel()

    @EnvironmentObject var navigation: CreateCardNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Creating your card ...")
                .font(.brandTitle1)
                .foregroundStyle(Color.primary)
            Text("This might take a moment")
                .font(.brandBody)
                .foregroundStyle(Color.secondary)
            Image("card-flattend")
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Spacer()
            }
            Spacer()
        }
        .padding(32)
        .frame(maxHeight: .infinity)
        .background(NuriAsset.background.swiftUIColor)
        .onChange(of: viewModel.viewState.isFinished) { _, newValue in
            if newValue {
                navigation.isPresented = false
            }
        }
        .task {
            await viewModel.createCard()
        }
    }
}
