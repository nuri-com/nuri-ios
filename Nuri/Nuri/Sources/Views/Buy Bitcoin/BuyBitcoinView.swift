import SwiftUI
import PassKit

struct BuyBitcoinView: View {

    @Binding var isPresented: Bool

    var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        return formatter
    }

    @State private var amount: Double? = 21

    @FocusState private var focusedField: Int?

    private let exchangeRate: Double = 91458.62

    var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>.logo(
                title: "Buy Bitcoin",
                onClose: { isPresented = false }
            )

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Text("€")
                        .font(.system(size: 40, weight: .semibold))
                    TextField("0", value: $amount, format: .number)
                        .setWidthAccordingTo(text: "\((amount ?? 0))")
                        .focused($focusedField, equals: 1)
                        .font(.system(size: 40, weight: .semibold))
                        .keyboardType(.decimalPad)
                        .tint(Color("PrimaryNuriLilac"))
                }
                Text("~ \(formatter.string(from: NSNumber(value: (amount ?? 0) / exchangeRate))!) BTC")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.secondary)
                Spacer()
                NavigationLink(destination: SuccessView(illustration: "hand-plant", title: "Bitcoin purchased!", subtitle: "You've purchased 0.9123 BTC!") {
                    isPresented = false
                }) {
                    NuriButton(icon: "bitcoin-circle", title: "Buy with Apple Pay", style: .primary)
                }
            }
            .padding()
        }
        .background(NuriAsset.background.swiftUIColor)
        .onAppear {
            focusedField = 1
        }
    }
}

#Preview {
    NavigationStack {
        BuyBitcoinView(isPresented: .constant(true))
    }
}
