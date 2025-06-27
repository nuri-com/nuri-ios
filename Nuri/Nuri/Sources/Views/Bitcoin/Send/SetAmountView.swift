import SwiftUI

struct SetAmountView: View {

    @State var amount: String = "0.00001337"

    @FocusState private var focusedField: Int?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigation: BitcoinViewNavigation

    var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>.backAndClose(
                title: "Confirm Amount",
                onBack: { dismiss() },
                onClose: { navigation.isSendViewPresented = false }
            )

            VStack {
                HStack {
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
        }
        .background(NuriAsset.background.swiftUIColor)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            focusedField = 1
        }
    }
}
