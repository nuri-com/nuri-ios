import SwiftUI
import PassKit

struct BuyBitcoinView: View {

    @Binding var isPresented: Bool

    var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        return formatter
    }

    @State private var amountText: String = "21"
    @State private var isPrimaryBTC = false // false = EUR primary

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
                    Text(isPrimaryBTC ? "₿" : "€ ")
                        .font(.system(size: 40, weight: .semibold))
                    TextField("0", text: $amountText)
                        .setWidthAccordingTo(text: amountText)
                        .focused($isFieldFocused)
                        .font(.system(size: 40, weight: .semibold))
                        .keyboardType(.decimalPad)
                        .tint(Color("PrimaryNuriLilac"))
                        .onChange(of: amountText) { newValue in
                            var sanitized = newValue.replacingOccurrences(of: ",", with: ".")
                            // keep digits and dot
                            sanitized = sanitized.filter { "0123456789.".contains($0) }
                            // allow only one dot
                            if let firstDot = sanitized.firstIndex(of: ".") {
                                let afterFirst = sanitized.index(after: firstDot)
                                sanitized = sanitized.prefix(upTo: afterFirst) + sanitized[afterFirst...].replacingOccurrences(of: ".", with: "")
                            }
                            // limit fraction length
                            if let dotIndex = sanitized.firstIndex(of: ".") {
                                let fractionStart = sanitized.index(after: dotIndex)
                                let fraction = sanitized[fractionStart...]
                                let limit = isPrimaryBTC ? 8 : 2
                                if fraction.count > limit {
                                    sanitized = String(sanitized[..<sanitized.index(dotIndex, offsetBy: limit + 1)])
                                }
                            }
                            if sanitized != newValue {
                                amountText = sanitized
                            }
                        }
                    Button(action: toggleCurrency) {
                        Image("transfer_vertical")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                Text(secondaryText())
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

    private func secondaryText() -> String {
        if isPrimaryBTC {
            let eur = amountValue * exchangeRate
            return "~ € " + formatter.string(from: NSNumber(value: eur))!
        } else {
            let btc = amountValue / exchangeRate
            return "~ " + formatter.string(from: NSNumber(value: btc))! + " BTC"
        }
    }

    private func toggleCurrency() {
        let current = amountValue
        let limit = isPrimaryBTC ? 2 : 8 // because we will toggle afterwards
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = limit
        formatter.numberStyle = .decimal

        if isPrimaryBTC {
            // BTC -> EUR (2 decimals)
            let eur = current * exchangeRate
            amountText = formatter.string(from: NSNumber(value: eur)) ?? ""
        } else {
            // EUR -> BTC (8 decimals)
            let btc = current / exchangeRate
            amountText = formatter.string(from: NSNumber(value: btc)) ?? ""
        }
        isPrimaryBTC.toggle()
    }

    private var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

#Preview {
    NavigationStack {
        BuyBitcoinView(isPresented: .constant(true))
    }
}
