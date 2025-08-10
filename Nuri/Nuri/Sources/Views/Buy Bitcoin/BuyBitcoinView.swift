import SwiftUI
import PassKit
import StrigaAPI

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
    
    // Bank account state
    @State private var isLoadingAccount = true
    @State private var ibanDetails: IBANDetails?
    @State private var accountError: String?
    
    struct IBANDetails {
        let iban: String
        let bic: String
        let accountHolderName: String
        let accountId: String
    }
    
    // Striga service
    private let striga = StrigaService.shared
    
    // Debug mode to test without Apple Pay
    #if DEBUG
    @State private var debugMode = false // Changed to false to test real Apple Pay
    #else
    @State private var debugMode = false
    #endif
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        
        // Ensure Striga is configured
        if striga.configuration == nil {
            striga.configuration = StrigaCredentials.current
            print("🏦 [BuyBitcoinView] Configured with Striga credentials")
        }
    }

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
    @State private var showCopiedToast = false
    @State private var copiedField: String = ""

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
                
                // IBAN Account Section
                VStack(spacing: 16) {
                    Text("Transfer EUR to buy Bitcoin")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#6D6D86"))
                    
                    if isLoadingAccount {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading bank account...")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#6D6D86"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#F5F5F7"))
                        .cornerRadius(12)
                    } else if let error = accountError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task {
                                    await loadOrCreateIBANAccount()
                                }
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("PrimaryNuriLilac"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#FFF5F5"))
                        .cornerRadius(12)
                    } else if let iban = ibanDetails {
                        VStack(alignment: .leading, spacing: 12) {
                            // IBAN Row
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("IBAN")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#6D6D86"))
                                    Text(iban.iban)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(Color("PrimaryNuriBlack"))
                                }
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = iban.iban
                                    copiedField = "IBAN"
                                    showCopiedToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopiedToast = false
                                    }
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color("PrimaryNuriLilac"))
                                }
                            }
                            
                            Divider()
                            
                            // BIC Row
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("BIC/SWIFT")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#6D6D86"))
                                    Text(iban.bic)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(Color("PrimaryNuriBlack"))
                                }
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = iban.bic
                                    copiedField = "BIC"
                                    showCopiedToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopiedToast = false
                                    }
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color("PrimaryNuriLilac"))
                                }
                            }
                            
                            Divider()
                            
                            // Account Holder Row
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Account Holder")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                                Text(iban.accountHolderName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            }
                        }
                        .padding()
                        .background(Color(hex: "#F5F5F7"))
                        .cornerRadius(12)
                        
                        // Info text
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                Text("Important:")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "#6D6D86"))
                            
                            Text("• Only send funds from accounts in your name\n• SEPA transfers arrive in 1-2 business days\n• SEPA Instant transfers arrive within seconds")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#6D6D86"))
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#FFF9E6"))
                        .cornerRadius(12)
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
        .overlay(
            Group {
                if showCopiedToast {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text("\(copiedField) copied!")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 50)
                    .animation(.easeInOut, value: showCopiedToast)
                }
            }
        )
        .onAppear {
            print("🟢 BuyBitcoinView appeared")
            isFieldFocused = true
            Task {
                await fetchPrice()
                await loadOrCreateIBANAccount()
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
    
    private func loadOrCreateIBANAccount() async {
        print("🏦 Loading IBAN account...")
        isLoadingAccount = true
        accountError = nil
        ibanDetails = nil
        
        // Get current user ID
        guard let userId = UserSettings().strigaUserId else {
            await MainActor.run {
                isLoadingAccount = false
                accountError = "No user ID found. Please complete registration first."
            }
            return
        }
        
        print("🏦 User ID: \(userId)")
        
        do {
            // Get all wallets for the user
            let walletsResponse = try await striga.getWallets(userId: userId)
            print("🏦 Got \(walletsResponse.wallets.count) wallets")
            
            // Look for existing EUR account
            var eurAccount: GetWalletsResponse.Account?
            for wallet in walletsResponse.wallets {
                if let eur = wallet.accounts.eur {
                    eurAccount = eur
                    break
                }
            }
            
            if let existingAccount = eurAccount {
                print("🏦 Found existing EUR account: \(existingAccount.accountId)")
                
                // Check if it already has IBAN
                if let bankingDetails = existingAccount.bankingDetails {
                    print("🏦 Account already has IBAN: \(bankingDetails.iban)")
                    await MainActor.run {
                        self.ibanDetails = IBANDetails(
                            iban: bankingDetails.iban,
                            bic: bankingDetails.bic,
                            accountHolderName: bankingDetails.accountHolderName,
                            accountId: existingAccount.accountId
                        )
                        self.isLoadingAccount = false
                    }
                } else {
                    // Enrich the account
                    print("🏦 Enriching account with IBAN...")
                    let enrichResponse = try await striga.enrichAccount(
                        EnrichAccount(accountId: existingAccount.accountId, userId: userId)
                    )
                    print("🏦 Account enriched successfully")
                    await MainActor.run {
                        self.ibanDetails = IBANDetails(
                            iban: enrichResponse.iban ?? "",
                            bic: enrichResponse.bic ?? "",
                            accountHolderName: enrichResponse.accountHolderName ?? "",
                            accountId: enrichResponse.accountId
                        )
                        self.isLoadingAccount = false
                    }
                }
            } else {
                // No EUR account found - this means the wallet wasn't created with EUR support
                // This should not happen in normal flow since CardCreationService creates a multi-currency wallet
                print("⚠️ No EUR account found in any wallet")
                print("⚠️ This indicates the wallet was not created with EUR support")
                print("⚠️ User should have a wallet created during card creation that includes EUR")
                
                await MainActor.run {
                    self.isLoadingAccount = false
                    self.accountError = "No EUR account found. Please contact support."
                }
            }
        } catch {
            print("❌ Error loading IBAN account: \(error)")
            await MainActor.run {
                self.isLoadingAccount = false
                self.accountError = "Failed to load bank account: \(error.localizedDescription)"
            }
        }
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
