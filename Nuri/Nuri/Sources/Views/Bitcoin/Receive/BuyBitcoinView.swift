import SwiftUI
import PassKit

struct BuyBitcoinView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation

    @State var amount: String = "99.50"

    @FocusState private var focusedField: Int?

    var body: some View {
        VStack {
            Text("Buy Bitcoin")
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
            Spacer()
            HStack(spacing: 8) {
                Text("€")
                    .font(.system(size: 40, weight: .semibold))
                TextFieldDynamicWidth(title: "0.00", text: $amount)
                .focused($focusedField, equals: 1)
                .font(.system(size: 40, weight: .semibold))
            }
            Text("~ 0.002 BTC")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            Spacer()
            NavigationLink("Buy with Apple Pay") {
                SuccessView(illustration: "hand-plant", title: "Bitcoin purchased!", subtitle: "You've purchased 0.9123 BTC!") {
                    navigation.isReceiveViewPresented = false
                }
            }
            .buttonStyle(ProminentBlackButtonStyle())
        }
        .padding()
    }
}

#Preview {
    BuyBitcoinView()
}
