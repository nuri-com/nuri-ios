import SwiftUI

struct SetAmountView: View {

    @State var amount: String = "0.00001337"

    @FocusState private var focusedField: Int?

    var body: some View {
        VStack {
            HStack {
                Text("Confirm Amount")
                    .font(.brandTitle1)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                Spacer()
                Text("↑↓ EUR")
                    .font(.caption)
                    .padding(2)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Spacer()
            HStack(spacing: 8) {
                Text("₿")
                    .font(.system(size: 40, weight: .semibold))
                TextField("", text: $amount)
                    .focused($focusedField, equals: 1)
                    .font(.system(size: 40, weight: .semibold))
            }
            Text("~ 11.23 EUR")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            Spacer()
            NavigationLink("Confirm Amount") {
                ConfirmTransactionView()
            }
            .buttonStyle(ProminentButtonStyle())
        }
        .padding(32)
        .background(NuriAsset.background.swiftUIColor)
        .navigationTitle("Send Bitcoin")
        .onAppear {
            focusedField = 1
        }
    }
}
