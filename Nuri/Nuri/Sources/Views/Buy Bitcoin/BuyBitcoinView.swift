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

    @State private var amountText: String = "21"

    private var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    @FocusState private var isFieldFocused: Bool

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
                    TextField("0", text: $amountText)
                        .setWidthAccordingTo(text: amountText)
                        .focused($isFieldFocused)
                        .font(.system(size: 40, weight: .semibold))
                        .keyboardType(.decimalPad)
                        .tint(Color("PrimaryNuriLilac"))
                        .onChange(of: amountText) { newValue in
                            // allow only digits and decimal separators
                            let filtered = newValue.filter { "0123456789,.".contains($0) }
                            if filtered != newValue {
                                amountText = filtered
                            }
                        }
                }
                Text("~ \(formatter.string(from: NSNumber(value: amountValue / exchangeRate))!) BTC")
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
            isFieldFocused = true
        }
    }
}

#Preview {
    NavigationStack {
        BuyBitcoinView(isPresented: .constant(true))
    }
}
