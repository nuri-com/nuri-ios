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
    @Binding public var exchangeRate: Double // reactive to parent changes
    public let availableBalance: UInt64? // Optional balance display
    let walletState: WalletStateManager? // For fee estimation

    public let actionIcon: String
    public let actionTitle: String
    public let onSubmit: (_ amount: Double, _ isCrypto: Bool) -> Void
    public let onClose: () -> Void

    // MARK: Internal state
    @State private var amountText: String = "" // start empty
    @State private var isPrimaryCrypto: Bool = false // Default to fiat (EUR)
    @FocusState private var isFieldFocused: Bool

    private var formatter: NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0 // No decimals allowed anywhere
        return f
    }

    init(title: String,
                primarySymbol: String,
                secondarySymbol: String,
                initialPrimaryIsCrypto: Bool,
                exchangeRate: Binding<Double>,
                availableBalance: UInt64? = nil,
                walletState: WalletStateManager? = nil,
                actionIcon: String,
                actionTitle: String,
                onSubmit: @escaping (_ amount: Double, _ isCrypto: Bool) -> Void,
                onClose: @escaping () -> Void) {
        self.title = title
        self.primarySymbol = primarySymbol
        self.secondarySymbol = secondarySymbol
        self.initialPrimaryIsCrypto = initialPrimaryIsCrypto
        self._exchangeRate = exchangeRate
        self.availableBalance = availableBalance
        self.walletState = walletState
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
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text(isPrimaryCrypto ? secondarySymbol : primarySymbol)
                            .font(.system(size: 40, weight: .semibold))
                        TextField("0", text: $amountText)
                            .setWidthAccordingTo(text: amountText)
                            .focused($isFieldFocused)
                            .font(.system(size: 40, weight: .semibold))
                            .keyboardType(.numberPad)
                            .tint(Color("PrimaryNuriLilac"))
                            .onChange(of: amountText, perform: { newValue in
                                print("📝 [AmountEntryScreen] Amount text changed: '\(newValue)'")
                                sanitizeInput(newValue)
                            })
                        Button(action: toggleCurrency) {
                            Image("transfer_vertical")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !amountText.isEmpty {
                        Text(secondaryDisplayText())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color("PrimaryNuriBlack"))
                    }
                }
                Spacer()
                
                // Fee and total display (only show when funds are sufficient)
                if (primarySymbol == "₿" || secondarySymbol == "₿") && walletState != nil && !amountText.isEmpty && !isInsufficientFunds {
                    Text("₿ \(String(UInt64(amountInSats))) Amount + ₿ \(String(estimatedFee)) Fee = ₿ \(String(totalAmountWithFee))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#6D6D86"))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                }
                
                Button(action: {
                    onSubmit(amountValue, isPrimaryCrypto)
                }) {
                    NuriButton(
                        icon: actionIcon, 
                        title: isInsufficientFunds ? "Insufficient Funds" : actionTitle, 
                        style: isInsufficientFunds ? .secondary : .primary
                    )
                }
                .disabled(isInsufficientFunds)
            }
            .padding()
        }
        .background(NuriAsset.background.swiftUIColor)
        .onAppear {
            isFieldFocused = true
            print("🎬 [AmountEntryScreen] onAppear: exchangeRate = \(exchangeRate)")
            // Auto-fetch price if not already provided
            if exchangeRate == 0 {
                Task {
                    await fetchPrice()
                }
            }
        }
        .onChange(of: exchangeRate) { newRate in
            print("📈 [AmountEntryScreen] Exchange rate updated: \(newRate)")
        }
    }

    // MARK: Helpers
    private func secondaryDisplayText() -> String {
        guard !amountText.isEmpty else { return "" }
        
        // Prevent calculations with extremely large numbers
        guard amountValue < 1_000_000_000_000 else { return "Amount too large" }
        
        // Use a safe default exchange rate if not set
        let safeRate = max(exchangeRate, 1.0) // Never allow zero or negative
        
        if isPrimaryCrypto {
            // When crypto is primary, we need to check which symbol we're actually showing
            if secondarySymbol == "₿" {
                // We toggled, so ₿ is now primary, meaning amountValue is in SATOSHIS
                // Convert sats to EUR: sats -> BTC -> EUR
                guard amountValue > 0 else { return "€ 0.00" }
                let btcValue = amountValue / 100_000_000
                let eurValue = btcValue * safeRate
                guard eurValue.isFinite && eurValue < Double.greatestFiniteMagnitude else {
                    return "€ --"
                }
                return "€ " + String(format: "%.2f", eurValue)
            } else {
                // Showing BTC, convert to EUR
                let eurValue = amountValue * safeRate
                guard eurValue.isFinite && eurValue < Double.greatestFiniteMagnitude else {
                    return "€ --"
                }
                return "€ " + String(format: "%.2f", eurValue)
            }
        } else {
            // Showing EUR, convert to sats
            if secondarySymbol == "₿" {
                guard amountValue > 0 && safeRate > 0 else { return "₿ 0" }
                // Check if division would be safe
                guard amountValue < safeRate * 21_000_000 else { return "₿ --" } // Max BTC supply
                let sats = (amountValue / safeRate) * 100_000_000
                guard sats.isFinite && sats > 0 && sats < 2_100_000_000_000_000 else {
                    return "₿ --"
                }
                return "₿ " + String(Int(min(sats, Double(Int.max))))
            } else {
                // EUR to BTC
                guard amountValue > 0 && safeRate > 0 else { return secondarySymbol + " 0" }
                let btcValue = amountValue / safeRate
                guard btcValue.isFinite && btcValue < 21_000_000 else {
                    return secondarySymbol + " --"
                }
                return secondarySymbol + " " + String(format: "%.8f", btcValue)
            }
        }
    }

    private func toggleCurrency() {
        let current = amountValue
        
        // Bounds check
        guard current >= 0 && current < 1_000_000_000_000 else {
            isPrimaryCrypto.toggle()
            return
        }
        
        // Use a safe default exchange rate if not set
        let safeRate = max(exchangeRate, 1.0)
        
        if isPrimaryCrypto { // Switching from Crypto to Fiat
            if secondarySymbol == "₿" {
                // We're showing ₿ as primary, so current is in SATOSHIS
                // Converting from sats to EUR
                let btcValue = current / 100_000_000
                let eurValue = btcValue * safeRate
                if eurValue.isFinite && eurValue > 0 && eurValue < 1_000_000_000 {
                    amountText = String(Int(round(eurValue)))
                } else {
                    amountText = "0"
                }
            } else {
                // Converting from BTC to EUR
                let eurValue = current * safeRate
                if eurValue.isFinite && eurValue > 0 && eurValue < 1_000_000_000 {
                    amountText = String(Int(round(eurValue)))
                } else {
                    amountText = "0"
                }
            }
        } else { // Switching from Fiat (EUR) to Crypto (sats)
            if secondarySymbol == "₿" {
                // Converting from EUR to sats
                guard safeRate > 0 else {
                    amountText = "0"
                    isPrimaryCrypto.toggle()
                    return
                }
                let satsValue = (current / safeRate) * 100_000_000
                if satsValue.isFinite && satsValue > 0 && satsValue < 2_100_000_000_000_000 {
                    amountText = String(Int(min(round(satsValue), Double(Int.max))))
                } else {
                    amountText = "0"
                }
            } else {
                // Converting from EUR to BTC
                guard safeRate > 0 else {
                    amountText = "0"
                    isPrimaryCrypto.toggle()
                    return
                }
                let btcValue = current / safeRate
                if btcValue.isFinite && btcValue > 0 && btcValue < 21_000_000 {
                    amountText = String(Int(round(btcValue)))
                } else {
                    amountText = "0"
                }
            }
        }
        isPrimaryCrypto.toggle()
    }

    private var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var amountInSats: Double {
        // Bounds check
        guard amountValue > 0 && amountValue < 1_000_000_000_000 else { return 0 }
        
        // Use a safe default exchange rate if not set
        let safeRate = max(exchangeRate, 1.0) // Never allow zero or negative
        
        if isPrimaryCrypto {
            // When crypto is primary, check what type of crypto
            if secondarySymbol == "₿" {
                // ₿ is now primary, so amountValue is already in satoshis
                return min(amountValue, 2_100_000_000_000_000) // Max supply in sats
            } else {
                // BTC is primary, convert to sats
                let sats = amountValue * 100_000_000
                return min(sats, 2_100_000_000_000_000)
            }
        } else {
            // EUR is primary, convert to sats
            guard safeRate > 0 else { return 0 }
            let sats = (amountValue / safeRate) * 100_000_000
            // Protect against NaN/Infinity and bounds
            guard sats.isFinite && sats > 0 else { return 0 }
            return min(sats, 2_100_000_000_000_000)
        }
    }

    private var estimatedFee: UInt64 {
        guard let walletState = walletState, !amountText.isEmpty else { return 0 }
        return walletState.feeRates.estimatedFee(amountSats: UInt64(amountInSats))
    }
    
    private var totalAmountWithFee: UInt64 {
        guard !amountText.isEmpty else { return 0 }
        return UInt64(amountInSats) + estimatedFee
    }
    
    private var isInsufficientFunds: Bool {
        guard let balance = availableBalance, !amountText.isEmpty else { return false }
        
        // Use a safe default exchange rate if not set
        let safeRate = exchangeRate > 0 ? exchangeRate : 50000.0
        
        // Check if this is a buy flow (EUR primary, BTC secondary)
        let isBuyFlow = primarySymbol == "€" && secondarySymbol == "₿"
        
        if isBuyFlow {
            // For buy flow, check EUR balance
            let eurAmount: Double
            if isPrimaryCrypto {
                // User toggled to BTC (sats) input, convert to EUR
                // When toggled, amountValue is in satoshis
                let btcValue = amountValue / 100_000_000
                eurAmount = btcValue * safeRate
            } else {
                // User is entering EUR directly
                eurAmount = amountValue
            }
            
            // Balance is passed as cents for buy flow
            let eurBalance = Double(balance) / 100.0
            let insufficient = eurAmount > eurBalance
            
            if insufficient {
                print("⚠️ [AmountEntryScreen] Insufficient EUR funds detected:")
                print("   💰 EUR amount needed: €\(eurAmount)")
                print("   💰 EUR balance available: €\(eurBalance)")
                print("   💰 Exceeds by: €\(eurAmount - eurBalance)")
            }
            
            return insufficient
        } else {
            // Original logic for send flow (checking Bitcoin balance)
            // Get the amount in satoshis regardless of current input currency
            let amountInSats: Double
            if isPrimaryCrypto {
                if secondarySymbol == "₿" {
                    // ₿ is primary, amountValue is already in satoshis
                    amountInSats = amountValue
                } else {
                    // BTC is primary, convert to sats
                    amountInSats = amountValue * 100_000_000
                }
            } else {
                // Primary is fiat (EUR)
                amountInSats = (amountValue / exchangeRate) * 100_000_000
            }
            
            // For Bitcoin transactions, include fee in the check
            let totalNeeded: UInt64
            if (primarySymbol == "₿" || secondarySymbol == "₿") && walletState != nil {
                totalNeeded = UInt64(amountInSats) + estimatedFee
            } else {
                totalNeeded = UInt64(amountInSats)
            }
            
            let insufficient = totalNeeded > balance
            
            if insufficient {
                print("⚠️ [AmountEntryScreen] Insufficient funds detected:")
                print("   💰 Input amount: \(amountValue) (\(isPrimaryCrypto ? primarySymbol : secondarySymbol))")
                print("   💰 Amount in sats: \(amountInSats)")
                print("   ⚡ Estimated fee: \(estimatedFee) sats")
                print("   💰 Total needed: \(totalNeeded) sats")
                print("   💰 Available balance: \(balance) sats")
                print("   💰 Exceeds by: \(totalNeeded - balance) sats")
            }
            
            return insufficient
        }
    }

    private func sanitizeInput(_ newValue: String) {
        // Only allow integers - no decimal points, commas, or any other characters
        var sanitized = newValue.filter { "0123456789".contains($0) }
        
        // Limit input length to prevent overflow (max 12 digits)
        if sanitized.count > 12 {
            sanitized = String(sanitized.prefix(12))
        }
        
        // Remove all leading zeros
        while sanitized.hasPrefix("0") && sanitized.count > 1 {
            sanitized = String(sanitized.dropFirst())
        }
        
        // If the string was all zeros, keep one zero
        if sanitized.isEmpty && newValue.contains("0") {
            sanitized = "0"
        }
        
        // Prevent extremely large numbers
        if let value = Double(sanitized), value > 999_999_999_999 {
            sanitized = "999999999999"
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
               let eurPerBtc = dict["EUR"] as? Double {
                await MainActor.run {
                    // If this is for ₿ (satoshis), convert BTC rate to sats rate
                    if primarySymbol == "₿" {
                        exchangeRate = eurPerBtc / 100_000_000
                    } else {
                        exchangeRate = eurPerBtc
                    }
                }
            }
        } catch {
            print("Price fetch failed", error)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var exchangeRate: Double = 0.00091929 // sats to EUR rate
        
        var body: some View {
            AmountEntryScreen(
                title: "Buy Bitcoin",
                primarySymbol: "₿",
                secondarySymbol: "€",
                initialPrimaryIsCrypto: true,
                exchangeRate: $exchangeRate,
                actionIcon: "bitcoin-circle",
                actionTitle: "Buy with Apple Pay",
                onSubmit: { _, _ in },
                onClose: {}
            )
        }
    }
    
    return PreviewWrapper()
} 