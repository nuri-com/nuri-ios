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

    @State private var amountText: String = ""
    @State private var isPrimaryBTC = true // start with ₿ (sats) primary

    @FocusState private var isFieldFocused: Bool

    @State private var exchangeRate: Double = 91458.62 // will update from API

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
                // Current BTC price label
                Text("1 ₿ = 1 sat ≈ € " + String(format: "%0.8f", exchangeRate / 100_000_000))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#6D6D86"))
                NavigationLink(destination: SuccessView(illustration: "hand-plant", title: "Bitcoin purchased!", subtitle: "You've purchased ₿91,230,000!") {
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
            Task {
                await fetchPrice()
            }
        }
    }

    private func secondaryText() -> String {
        if isPrimaryBTC {
            let eur = amountValue * exchangeRate
            let twoDec = String(format: "%0.2f", eur)
            return "~ € " + twoDec
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
            amountText = String(format: "%0.2f", eur)
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

    // MARK: - Networking

    private func fetchPrice() async {
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eur = dict["EUR"] as? Double {
                DispatchQueue.main.async {
                    exchangeRate = eur
                }
            }
        } catch {
            print("Price fetch failed", error)
        }
    }
}

#Preview {
    NavigationStack {
        BuyBitcoinView(isPresented: .constant(true))
    }
}
