import SwiftUI

struct BitcoinPurchasedView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("hand-plant")
            Text("Bitcoin purchased!")
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
            Text("You've purchased 0.9123 BTC!")
            Spacer()
            Button("Done") {
                navigation.isReceiveViewPresented = false
            }
            .buttonStyle(ProminentBlackButtonStyle())
        }
        .padding()
        .background(NuriAsset.accentColor.swiftUIColor)
    }
}
