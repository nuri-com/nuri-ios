import SwiftUI

/// Custom amount entry screen for buying Bitcoin with EUR
/// This handles EUR balance validation instead of BTC balance
struct BuyAmountEntryScreen: View {
    let title: String
    let eurBalance: Double
    @Binding var btcToEurRate: Double
    let onSubmit: (_ btcAmount: Double, _ eurAmount: Double) -> Void
    let onClose: () -> Void
    
    @State private var amountText: String = ""
    @State private var isPrimaryCrypto: Bool = false // Start with EUR
    @FocusState private var isFieldFocused: Bool
    
    private var amountValue: Double {
        Double(amountText) ?? 0
    }
    
    private var eurAmount: Double {
        if isPrimaryCrypto {
            // BTC is primary, convert to EUR
            return amountValue * btcToEurRate
        } else {
            // EUR is primary
            return amountValue
        }
    }
    
    private var btcAmount: Double {
        if isPrimaryCrypto {
            // BTC is primary (in sats)
            return amountValue / 100_000_000
        } else {
            // EUR is primary, convert to BTC
            return amountValue / btcToEurRate
        }
    }
    
    private var btcSats: Double {
        return btcAmount * 100_000_000
    }
    
    private var isInsufficientFunds: Bool {
        guard !amountText.isEmpty else { return false }
        
        // Always check against EUR balance
        let totalEUR = eurAmount + (eurAmount * 0.02) // Include 2% fee
        return totalEUR > eurBalance
    }
    
    private var secondaryText: String {
        if amountText.isEmpty { return "" }
        
        if isPrimaryCrypto {
            // Primary is BTC (sats), show EUR
            return String(format: "€ %.2f", eurAmount)
        } else {
            // Primary is EUR, show BTC
            return "₿ \(Int(btcSats))"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>.logo(title: title, onClose: onClose)
            
            VStack {
                Spacer()
                
                VStack(spacing: 4) {
                    // Amount input
                    HStack(spacing: 8) {
                        Text(isPrimaryCrypto ? "₿" : "€")
                            .font(.system(size: 40, weight: .semibold))
                        
                        TextField("0", text: $amountText)
                            .setWidthAccordingTo(text: amountText)
                            .focused($isFieldFocused)
                            .font(.system(size: 40, weight: .semibold))
                            .keyboardType(.numberPad)
                            .tint(Color("PrimaryNuriLilac"))
                            .onChange(of: amountText, perform: sanitizeInput)
                        
                        Button(action: toggleCurrency) {
                            Image("transfer_vertical")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                    }
                    
                    // Secondary display
                    if !secondaryText.isEmpty {
                        Text(secondaryText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#6D6D86"))
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Fee info
                if !amountText.isEmpty {
                    VStack(spacing: 4) {
                        Text("Processing fee: € \(String(format: "%.2f", eurAmount * 0.02))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#6D6D86"))
                        
                        Text("Total: € \(String(format: "%.2f", eurAmount * 1.02))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#6D6D86"))
                    }
                    .padding(.vertical, 8)
                }
                
                // Keypad
                VStack(spacing: 1) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 1) {
                            ForEach(1..<4) { col in
                                let digit = row * 3 + col
                                KeypadButton(label: "\(digit)") {
                                    amountText += "\(digit)"
                                }
                            }
                        }
                    }
                    HStack(spacing: 1) {
                        KeypadButton(label: "") { }
                            .disabled(true)
                            .opacity(0)
                        KeypadButton(label: "0") {
                            if amountText != "0" {
                                amountText += "0"
                            }
                        }
                        KeypadButton(label: "⌫") {
                            if !amountText.isEmpty {
                                amountText.removeLast()
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
                
                // Submit button
                Button(action: submit) {
                    if isInsufficientFunds {
                        NuriButton(
                            icon: "money_topup",
                            title: "Insufficient Funds",
                            style: .secondary
                        )
                    } else {
                        NuriButton(
                            icon: "money_topup",
                            title: "Confirm Amount",
                            style: amountText.isEmpty ? .secondary : .primary
                        )
                    }
                }
                .disabled(amountText.isEmpty || isInsufficientFunds)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "#F0F0F0"))
        .onAppear {
            isFieldFocused = false
        }
    }
    
    private func toggleCurrency() {
        guard !amountText.isEmpty else { return }
        
        if isPrimaryCrypto {
            // Converting from BTC (sats) to EUR
            let current = amountValue
            let btc = current / 100_000_000
            let eurValue = btc * btcToEurRate
            amountText = String(Int(round(eurValue)))
        } else {
            // Converting from EUR to BTC (sats)
            let current = amountValue
            let btcValue = current / btcToEurRate
            let satsValue = btcValue * 100_000_000
            amountText = String(Int(round(satsValue)))
        }
        
        isPrimaryCrypto.toggle()
    }
    
    private func sanitizeInput(_ newValue: String) {
        var sanitized = newValue.filter { "0123456789".contains($0) }
        
        // Remove leading zeros
        while sanitized.hasPrefix("0") && sanitized.count > 1 {
            sanitized = String(sanitized.dropFirst())
        }
        
        if sanitized.isEmpty && newValue.contains("0") {
            sanitized = "0"
        }
        
        if sanitized != newValue {
            amountText = sanitized
        }
    }
    
    private func submit() {
        guard !amountText.isEmpty && !isInsufficientFunds else { return }
        onSubmit(btcAmount, eurAmount)
    }
}

// Keypad button component
private struct KeypadButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 24, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.white)
                .foregroundColor(Color("PrimaryNuriBlack"))
        }
    }
}

// Note: setWidthAccordingTo extension is already defined in AmountEntryScreen.swift

#Preview {
    BuyAmountEntryScreen(
        title: "€ 314.11 Balance",
        eurBalance: 314.11,
        btcToEurRate: .constant(95000),
        onSubmit: { btc, eur in
            print("BTC: \(btc), EUR: \(eur)")
        },
        onClose: {
            print("Closed")
        }
    )
}