import SwiftUI
import PassKit

// Apple Pay Button wrapper
struct ApplePayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        button.isUserInteractionEnabled = false // Let SwiftUI handle the tap
        return button
    }
    
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {
        // No updates needed
    }
}

// Apple Pay Coordinator to handle delegate callbacks
class ApplePayCoordinator: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    let onSuccess: () -> Void
    
    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        print("🔵 Apple Pay dialog finished/cancelled")
        controller.dismiss(animated: true)
    }
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController,
                                          didAuthorizePayment payment: PKPayment,
                                          handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        
        print("💳 Payment authorized!")
        
        // Log payment method details
        let paymentMethod = payment.token.paymentMethod
        if let network = paymentMethod.network {
            print("💳 Payment network: \(network)")
        }
        print("💳 Card type: \(paymentMethod.type.rawValue)")
        if let displayName = paymentMethod.displayName {
            print("💳 Card display name: \(displayName)")
        }
        
        // Store user information for later use
        if let billingContact = payment.billingContact {
            print("📧 Billing contact received")
            // TODO: Store this data in your user model/database
            // For now, we'll just process it without displaying
            
            var userData: [String: Any] = [:]
            
            if let name = billingContact.name {
                userData["name"] = PersonNameComponentsFormatter.localizedString(from: name, style: .default)
            }
            
            if let email = billingContact.emailAddress {
                userData["email"] = email
            }
            
            if let phone = billingContact.phoneNumber?.stringValue {
                userData["phone"] = phone
            }
            
            if let address = billingContact.postalAddress {
                userData["address"] = [
                    "street": address.street,
                    "city": address.city,
                    "state": address.state,
                    "postalCode": address.postalCode,
                    "country": address.country
                ]
            }
            
            // Store payment token
            userData["paymentToken"] = payment.token
            
            // TODO: Send userData to your backend or store locally
        }
        
        // Complete the payment
        // For testing: always return success without processing
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        
        // Navigate to success screen
        DispatchQueue.main.async {
            self.onSuccess()
        }
    }
}

struct BuyBitcoinView: View {

    @Binding var isPresented: Bool
    @State private var applePayCoordinator: ApplePayCoordinator?
    
    // Debug mode to test without Apple Pay
    #if DEBUG
    @State private var debugMode = false // Changed to false to test real Apple Pay
    #else
    @State private var debugMode = false
    #endif

    var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        return formatter
    }

    @State private var amountText: String = ""
    @State private var isPrimaryBTC = false // start with € primary

    @FocusState private var isFieldFocused: Bool

    @State private var exchangeRate: Double = 0 // will update from API
    @State private var shouldNavigateToSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            NuriHeader<AnyView, AnyView>.logo(
                title: "Buy Bitcoin",
                onClose: { isPresented = false }
            )

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Text(isPrimaryBTC ? "₿" : "€")
                        .font(.system(size: 40, weight: .semibold))
                    TextField("0", text: $amountText)
                        .setWidthAccordingTo(text: amountText)
                        .focused($isFieldFocused)
                        .font(.system(size: 40, weight: .semibold))
                        .keyboardType(.decimalPad)
                        .tint(Color("PrimaryNuriLilac"))
                        .onChange(of: amountText) { newValue in
                            print("💰 Amount changed: '\(newValue)' -> value: \(amountValue)")
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
                if !amountText.isEmpty {
                    Text(secondaryText())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                // Current BTC price label - only show if exchange rate is loaded
                if exchangeRate > 0 {
                    Text("€ \(formatEuro(exchangeRate)) / Bitcoin")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#6D6D86"))
                }
                // Show Apple Pay button only when payments can be made
                if PKPaymentAuthorizationViewController.canMakePayments() {
                    // Using Apple's official PKPaymentButton
                    Button(action: {
                        print("🔵 Apple Pay button tapped")
                        print("🔵 Amount value: \(amountValue)")
                        print("🔵 Exchange rate: \(exchangeRate)")
                        print("🔵 Is primary BTC: \(isPrimaryBTC)")
                        if amountValue > 0 {
                            startApplePayment()
                        } else {
                            print("❌ Cannot start payment: amount is 0")
                        }
                    }) {
                        ApplePayButton()
                            .frame(height: 56)
                            .cornerRadius(28)
                    }
                    .buttonStyle(.plain)
                    .disabled(amountValue == 0)
                    .opacity(amountValue == 0 ? 0.5 : 1.0)
                } else {
                    NavigationLink(destination: SuccessView(illustration: "hand-plant", title: "Bitcoin purchased!", subtitle: "You've purchased ₿ 91,230,000!") {
                        isPresented = false
                    }) {
                        NuriButton(icon: "bitcoin-circle", title: "Buy with Apple Pay", style: .primary)
                    }
                }
            }
            .padding()
        }
        .background(NuriAsset.background.swiftUIColor)
        .navigationDestination(isPresented: $shouldNavigateToSuccess) {
            SuccessView(illustration: "hand-plant", title: "Bitcoin purchased!", subtitle: "You've purchased ₿ 91,230,000!") {
                isPresented = false
            }
        }
        .onAppear {
            print("🟢 BuyBitcoinView appeared")
            print("🟢 Can make payments: \(PKPaymentAuthorizationViewController.canMakePayments())")
            print("🟢 Can make payments with cards: \(PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex, .discover]))")
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
            return "€ " + twoDec
        } else {
            let sats = (amountValue / exchangeRate) * 100_000_000
            let satsFormatter = NumberFormatter()
            satsFormatter.locale = Locale(identifier: "en_US_POSIX")
            satsFormatter.numberStyle = .decimal
            satsFormatter.maximumFractionDigits = 0
            satsFormatter.usesGroupingSeparator = true
            let formattedSats = satsFormatter.string(from: NSNumber(value: sats)) ?? "0"
            return "₿ " + formattedSats + " sats"
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

    // MARK: - Networking

    private func fetchPrice() async {
        print("🟡 Fetching Bitcoin price...")
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { 
            print("❌ Invalid URL for price fetch")
            return 
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eur = dict["EUR"] as? Double {
                DispatchQueue.main.async {
                    self.exchangeRate = eur
                    print("✅ Exchange rate loaded: €\(eur) per BTC")
                }
            } else {
                print("❌ Failed to parse price data")
            }
        } catch {
            print("❌ Price fetch failed: \(error)")
        }
    }
    
    private func formatEuro(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? ""
    }
    
    private func startApplePayment() {
        // Debug mode: skip Apple Pay and go directly to success
        if debugMode {
            print("DEBUG: Simulating Apple Pay purchase")
            print("Amount: \(isPrimaryBTC ? amountValue : amountValue / exchangeRate) BTC")
            print("EUR: \(isPrimaryBTC ? amountValue * exchangeRate : amountValue)")
            shouldNavigateToSuccess = true
            return
        }
        
        // Validate amount
        guard amountValue > 0 else {
            print("Error: Amount must be greater than 0")
            return
        }
        
        guard exchangeRate > 0 else {
            print("Error: Exchange rate not loaded")
            return
        }
        
        let paymentAmount = isPrimaryBTC ? amountValue * exchangeRate : amountValue
        
        print("Starting Apple Pay payment")
        print("Payment amount: €\(paymentAmount)")
        print("Bitcoin amount: \(isPrimaryBTC ? amountValue : amountValue / exchangeRate) BTC")
        
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.nuri.ios"
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "DE" // Germany
        request.currencyCode = "EUR"
        
        // Request user contact information
        request.requiredBillingContactFields = [.name, .emailAddress, .phoneNumber, .postalAddress]
        
        let bitcoinAmount = isPrimaryBTC ? amountValue : amountValue / exchangeRate
        let bitcoinItem = PKPaymentSummaryItem(
            label: "Bitcoin (\(String(format: "%.8f", bitcoinAmount)) BTC)",
            amount: NSDecimalNumber(value: paymentAmount)
        )
        request.paymentSummaryItems = [bitcoinItem]
        
        // Create coordinator
        applePayCoordinator = ApplePayCoordinator(onSuccess: {
            self.shouldNavigateToSuccess = true
        })
        
        if let paymentVC = PKPaymentAuthorizationViewController(paymentRequest: request) {
            print("✅ PKPaymentAuthorizationViewController created successfully")
            paymentVC.delegate = applePayCoordinator
            
            // Find the topmost view controller to present from
            print("🔍 Looking for window scene...")
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                print("✅ Found window scene")
                if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    print("✅ Found key window")
                    if let rootVC = window.rootViewController {
                        print("✅ Found root view controller: \(type(of: rootVC))")
                        
                        var topVC = rootVC
                        while let presented = topVC.presentedViewController {
                            print("🔍 Found presented controller: \(type(of: presented))")
                            topVC = presented
                        }
                        
                        print("🚀 Presenting Apple Pay from: \(type(of: topVC))")
                        topVC.present(paymentVC, animated: true)
                    } else {
                        print("❌ No root view controller found")
                    }
                } else {
                    print("❌ No key window found")
                }
            } else {
                print("❌ No window scene found")
            }
        } else {
            print("❌ Failed to create PKPaymentAuthorizationViewController")
            print("❌ Merchant ID: \(request.merchantIdentifier)")
            print("❌ Amount: \(paymentAmount)")
            print("❌ Payment items: \(request.paymentSummaryItems.map { "\($0.label): \($0.amount)" })")
        }
    }
}

#Preview {
    NavigationStack {
        BuyBitcoinView(isPresented: .constant(true))
    }
}
