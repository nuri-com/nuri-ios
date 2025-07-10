import SwiftUI
import PassKit

/// A reusable sheet-style screen for entering a crypto or fiat amount with a numeric keypad.
/// It replicates the layout of the original *Buy Bitcoin* view but exposes the
/// key pieces as parameters so other flows (sell, top-up, etc.) can reuse it.
///
/// Usage example:
/// ```swift
/// AmountEntryScreen(
///     title: "Buy Bitcoin",
///     primarySymbol: "₿",
///     secondarySymbol: "€",
///     initialPrimaryIsCrypto: true,
///     exchangeRate: 91929,
///     actionIcon: "bitcoin-circle",
///     actionTitle: "Buy with Apple Pay",
///     onSubmit: { amount, isCrypto in /* handle */ },
///     onClose: { dismiss() }
/// )
/// ```
public struct AmountEntryScreen: View {

    // MARK: Public API
    public let title: String
    public let primarySymbol: String
    public let secondarySymbol: String
    public let initialPrimaryIsCrypto: Bool
    @State public var exchangeRate: Double // allows live updates

    public let actionIcon: String
    public let actionTitle: String
    public let onSubmit: (_ amount: Double, _ isCrypto: Bool) -> Void
    public let onClose: () -> Void

    // MARK: Internal state
    @State private var amountText: String = "" // start empty
    @State private var isPrimaryCrypto: Bool = true
    @FocusState private var isFieldFocused: Bool

    private var formatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        // For ₿ (satoshis), no decimal places allowed. For other currencies, use appropriate decimals
        f.maximumFractionDigits = (isPrimaryCrypto && primarySymbol == "₿") ? 0 : (isPrimaryCrypto ? 8 : 2)
        return f
    }

    public init(title: String,
                primarySymbol: String,
                secondarySymbol: String,
                initialPrimaryIsCrypto: Bool,
                exchangeRate: Double,
                actionIcon: String,
                actionTitle: String,
                onSubmit: @escaping (_ amount: Double, _ isCrypto: Bool) -> Void,
                onClose: @escaping () -> Void) {
        self.title = title
        self.primarySymbol = primarySymbol
        self.secondarySymbol = secondarySymbol
        self.initialPrimaryIsCrypto = initialPrimaryIsCrypto
        self._exchangeRate = State(initialValue: exchangeRate)
        self.actionIcon = actionIcon
        self.actionTitle = actionTitle
        self.onSubmit = onSubmit
        self.onClose = onClose
        self._isPrimaryCrypto = State(initialValue: initialPrimaryIsCrypto)
    }

    // MARK: View
    public var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>.logo(title: title, onClose: onClose)

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Text(isPrimaryCrypto ? primarySymbol : secondarySymbol)
                        .font(.system(size: 40, weight: .semibold))
                    TextField("0", text: $amountText)
                        .setWidthAccordingTo(text: amountText)
                        .focused($isFieldFocused)
                        .font(.system(size: 40, weight: .semibold))
                        .keyboardType((isPrimaryCrypto && primarySymbol == "₿") ? .numberPad : .decimalPad)
                        .tint(Color("PrimaryNuriLilac"))
                        .onChange(of: amountText, perform: sanitizeInput)
                    Button(action: toggleCurrency) {
                        Image("transfer_vertical")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                Text(secondaryDisplayText())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text(primarySymbol == "₿" ? 
                     "1 ₿ = 1 sat ≈ € " + String(format: "%0.8f", exchangeRate) :
                     "1 BTC ≈ € " + String(format: "%0.2f", exchangeRate))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#6D6D86"))
                Button(action: {
                    onSubmit(amountValue, isPrimaryCrypto)
                }) {
                    NuriButton(icon: actionIcon, title: actionTitle, style: .primary)
                }
            }
            .padding()
        }
        .background(NuriAsset.background.swiftUIColor)
        .onAppear {
            isFieldFocused = true
            if exchangeRate == 0 && primarySymbol == "₿" {
                Task {
                    await fetchPrice()
                }
            }
        }
    }

    // MARK: Helpers
    private func secondaryDisplayText() -> String {
        guard !amountText.isEmpty else { return "" }
        if isPrimaryCrypto {
            let eur = amountValue * exchangeRate
            let twoDec = String(format: "%0.2f", eur)
            return "~ " + secondarySymbol + " " + twoDec
        } else {
            let btc = amountValue / exchangeRate
            return "~ " + formatter.string(from: NSNumber(value: btc))! + " " + primarySymbol
        }
    }

    private func toggleCurrency() {
        let current = amountValue
        
        if isPrimaryCrypto { // Switching from Crypto to Fiat (e.g., sats to EUR)
            let fiat = current * exchangeRate
            if fiat == 0 {
                amountText = "0"
            } else {
                amountText = String(format: "%0.2f", fiat)
            }
        } else { // Switching from Fiat to Crypto (e.g., EUR to sats)
            let crypto = current / exchangeRate
            if primarySymbol == "₿" {
                // For satoshis, show as integer
                amountText = String(Int(crypto))
            } else {
                // For other crypto, use decimal format
                let limit = 8
                let f = NumberFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.minimumFractionDigits = 0
                f.maximumFractionDigits = limit
                f.numberStyle = .decimal
                amountText = f.string(from: NSNumber(value: crypto)) ?? ""
            }
        }
        isPrimaryCrypto.toggle()
    }

    private var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func sanitizeInput(_ newValue: String) {
        var sanitized: String
        
        // For ₿ (satoshis), only allow integers - no decimal points or commas
        if isPrimaryCrypto && primarySymbol == "₿" {
            sanitized = newValue.filter { "0123456789".contains($0) }
        } else {
            // For other currencies, allow decimal input
            sanitized = newValue.replacingOccurrences(of: ",", with: ".")
            sanitized = sanitized.filter { "0123456789.".contains($0) }
            if let firstDot = sanitized.firstIndex(of: ".") {
                let after = sanitized.index(after: firstDot)
                sanitized = sanitized.prefix(upTo: after) + sanitized[after...].replacingOccurrences(of: ".", with: "")
            }
            if let dot = sanitized.firstIndex(of: ".") {
                let fractionStart = sanitized.index(after: dot)
                let fraction = sanitized[fractionStart...]
                let limit = isPrimaryCrypto ? 8 : 2
                if fraction.count > limit {
                    sanitized = String(sanitized[..<sanitized.index(dot, offsetBy: limit + 1)])
                }
            }
        }
        
        if sanitized != newValue {
            amountText = sanitized
        }
    }

    // MARK: - Networking (simple mempool.space price)
    private func fetchPrice() async {
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eur = dict["EUR"] as? Double {
                await MainActor.run {
                    exchangeRate = eur
                }
            }
        } catch {
            print("Price fetch failed", error)
        }
    }
}

#Preview {
    AmountEntryScreen(
        title: "Buy Bitcoin",
        primarySymbol: "₿",
        secondarySymbol: "€",
        initialPrimaryIsCrypto: true,
        exchangeRate: 91929,
        actionIcon: "bitcoin-circle",
        actionTitle: "Buy with Apple Pay",
        onSubmit: { _, _ in },
        onClose: {}
    )
} 