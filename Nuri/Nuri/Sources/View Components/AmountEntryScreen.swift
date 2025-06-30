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
        f.maximumFractionDigits = isPrimaryCrypto ? 8 : 2
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
                        .keyboardType(.decimalPad)
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
                Text("1 BTC ≈ € " + String(format: "%0.2f", exchangeRate))
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
        let limit = isPrimaryCrypto ? 2 : 8
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = limit
        f.numberStyle = .decimal

        if isPrimaryCrypto {
            let fiat = current * exchangeRate
            amountText = String(format: "%0.2f", fiat)
        } else {
            let btc = current / exchangeRate
            amountText = f.string(from: NSNumber(value: btc)) ?? ""
        }
        isPrimaryCrypto.toggle()
    }

    private var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func sanitizeInput(_ newValue: String) {
        var sanitized = newValue.replacingOccurrences(of: ",", with: ".")
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
        if sanitized != newValue {
            amountText = sanitized
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