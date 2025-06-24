import SwiftUI
import PassKit

struct BuyBitcoinView: View {

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
                BitcoinPurchasedView()
            }
            .buttonStyle(ProminentBlackButtonStyle())
        }
        .padding()
    }
}

#Preview {
    BuyBitcoinView()
}
