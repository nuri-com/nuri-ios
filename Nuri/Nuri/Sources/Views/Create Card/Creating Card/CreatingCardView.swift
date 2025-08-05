import SwiftUI

struct CreatingCardView: View {

    @ObservedObject var viewModel = CreatingCardViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigation: CreateCardNavigation
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>(title: "") {
                AnyView(
                    Image("HeaderLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                )
            } trailing: {
                AnyView(EmptyView())
            }
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
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NuriAsset.background.swiftUIColor)
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.viewState.isFinished) { _, newValue in
            if newValue {
                print("[CreatingCardView] Card creation finished, dismissing view")
                
                // Dismiss the entire navigation stack
                Task { @MainActor in
                    // Give time for UserSettings to be saved
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Set the binding to false to dismiss this view
                    isPresented = false
                    
                    // Also dismiss the entire card creation flow
                    navigation.isPresented = false
                }
            }
        }
        .task {
            await viewModel.createCard()
        }
    }
}
