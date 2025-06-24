import SwiftUI

struct BitcoinSentView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("bitcoin-sent")
            Text("Bitcoin sent!")
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
            Text("You've sent 0.9123 BTC!")
            Spacer()
            Button("Done") {
                navigation.isSendViewPresented = false
            }
            .buttonStyle(ProminentBlackButtonStyle())
        }
        .padding()
        .background(NuriAsset.accentColor.swiftUIColor)
    }
}
