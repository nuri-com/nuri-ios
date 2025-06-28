import SwiftUI

struct SuccessView: View {

    let illustration: String
    let title: String
    let subtitle: String
    let completion: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header with logo and close button
            NuriHeader<AnyView, AnyView>.logo(
                title: "",
                onClose: { completion() }
            )
            Spacer()
            Image(illustration)
            Text(title)
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
            Text(subtitle)
            Spacer()
            Button("Done") {
                completion()
            }
            .buttonStyle(ProminentBlackButtonStyle())
        }
        .padding()
        .background(NuriAsset.primaryNuriLilac.swiftUIColor)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
