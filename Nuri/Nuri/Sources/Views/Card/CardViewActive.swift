import SwiftUI
import UIKit
import StrigaAPI

struct CardViewActive: View {
    @State private var isTransactionsPresented = false
    @State private var showCardDetails = false
    @State private var isLargeQRPresented = false
    @State private var isCardFrozen = false
    @State private var isTopUpPresented = false
    @State private var isShareSheetPresented = false
    @State private var qrImage: UIImage? = nil
    @State private var walletBalance = "€0.00"
    @State private var cardHolderName = "Loading..."
    @State private var cardNumber = ""
    @State private var cardExpiry = ""
    @State private var cardCVV = ""
    @State private var showVerification = false
    @State private var cardAuthToken: String?
    
    private let striga = StrigaService.shared
    private let btcAddress = "bc1qsmd4xz68a7fhwvhjkd0cawx4uvs9a43746xld4yh0spfmwefpr5qc9wvv6"

    var body: some View {
        VStack(spacing: 0) {
            // Unified header
            NuriHeader<AnyView, AnyView>(title: "") {
                AnyView(
                    Image("HeaderLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 32, height: 32)
                )
            } trailing: {
                AnyView(
                    Button(action: {
                        isTopUpPresented = true
                    }) {
                        Text("+ Add Money")
                            .font(.custom("Inter", size: 14).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color("PrimaryNuriBlack"))
                            .cornerRadius(64)
                    }
                )
            }

            VStack {
                Spacer()
                NuriTitleWithSubtitle(title: walletBalance, subtitle: "Available Balance")
                .padding(.bottom, 30)

                let cardOpacity = isCardFrozen ? 0.4 : 1.0

                if showCardDetails {
                    CardMini(card: CardModel(holder: cardHolderName, number: cardNumber, expiry: cardExpiry, cvv: cardCVV), qrAddress: btcAddress, onQRTap: { isLargeQRPresented = true })
                        .transition(.opacity)
                        .opacity(cardOpacity)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                } else {
                    NuriCardIllustration()
                        .opacity(cardOpacity)
                        .padding(.bottom, 30)
                }

                HStack(spacing: 32) {
                    SmallIconButton(icon: showCardDetails ? "eye" : "eye_hidden", 
                                  title: showCardDetails ? "Hide" : "Show") {
                        print("[CardViewActive] Show/Hide button pressed")
                        print("[CardViewActive] Current showCardDetails: \(showCardDetails)")
                        if showCardDetails {
                            print("[CardViewActive] Hiding card details")
                            // Hide card details
                            showCardDetails = false
                            cardAuthToken = nil
                            // Clear sensitive data
                            cardNumber = ""
                            cardExpiry = ""
                            cardCVV = ""
                        } else {
                            print("[CardViewActive] Showing verification sheet")
                            print("[CardViewActive] Setting showVerification = true")
                            // Always show verification to get fresh card details
                            showVerification = true
                        }
                    }
                    SmallIconButton(icon: isCardFrozen ? "lock" : "lock_open", title: isCardFrozen ? "Unfreeze" : "Freeze") {
                        isCardFrozen.toggle()
                    }
                    SmallIconButton(icon: "money_topup", title: "Top-Up") {
                        isTopUpPresented = true
                    }
                }
                .padding(.bottom, 30)

                Button(action: {

                }) {
                    HStack(spacing: 8) {
                        Image("apple-wallet")
                            .resizable()
                            .frame(width: 32, height: 32)
                        Text("Add to Apple Wallet")
                            .font(.brandBody)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color("PrimaryNuriBlack"))
                    .cornerRadius(100)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)

            // Place the transactions button at the bottom, outside the main content stack
            Button(action: {
                isTransactionsPresented = true
            }) {
                Image("link-icon-to-transactions")
                    .resizable()
                    .frame(width: 24, height: 13)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(NuriAsset.background.swiftUIColor)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $isTransactionsPresented) {
            TransactionsView()
        }
        .sheet(isPresented: $isTopUpPresented) {
            NavigationStack {
                TopUpCardView(isPresented: $isTopUpPresented)
            }
        }
        .onAppear {
            loadCardData()
        }
        .sheet(isPresented: $showVerification) {
            CardVerificationView(isPresented: $showVerification) { authToken in
                print("[CardViewActive] Verification successful, received authToken")
                // On successful verification
                cardAuthToken = authToken
                showCardDetails = true
                Task {
                    await loadRealCardData(authToken: authToken)
                }
            }
            .onAppear {
                print("[CardViewActive] Verification sheet appeared")
                print("[CardViewActive] Current session data:")
                print("[CardViewActive] - userId: \(StrigaSession.shared.userId ?? "nil")")
                print("[CardViewActive] - cardId: \(StrigaSession.shared.cardId ?? "nil")")
            }
            .onDisappear {
                print("[CardViewActive] Verification sheet disappeared")
            }
        }
        .fullScreenCover(isPresented: $isLargeQRPresented) {
            GeometryReader { geo in
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        QRCodeImage(text: btcAddress)
                            .frame(width: min(geo.size.width, geo.size.height) * 0.8,
                                   height: min(geo.size.width, geo.size.height) * 0.8)
                            .onAppear {
                                UIPasteboard.general.string = btcAddress
                                let renderer = ImageRenderer(content:
                                    QRCodeImage(text: btcAddress)
                                        .frame(width: 300, height: 300)
                                )
                                if let uiImage = renderer.uiImage {
                                    qrImage = uiImage
                                }
                            }
                            .onTapGesture { isLargeQRPresented = false }
                    }
                    Text("Bitcoin address copied to clipboard")
                        .font(.headline)
                        .padding()
                    Button(action: {
                        isShareSheetPresented = true
                    }) {
                        NuriButton(icon: "share", title: "Share Address", style: .primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.white.opacity(0.95).ignoresSafeArea())
                .sheet(isPresented: $isShareSheetPresented) {
                    if let qrImage = qrImage {
                        ShareSheet(activityItems: [qrImage, btcAddress])
                    } else {
                        ShareSheet(activityItems: [btcAddress])
                    }
                }
            }
        }
    }
    
    private func loadCardData() {
        // Load basic card info (non-sensitive)
        if let name = StrigaSession.shared.name {
            cardHolderName = name
        }
        
        // Store IDs in session for later use
        if let userId = UserSettings().strigaUserId {
            StrigaSession.shared.userId = userId
            print("[CardView] Loaded userId: \(userId)")
        }
        if let cardId = UserSettings().strigaCardId {
            StrigaSession.shared.cardId = cardId
            print("[CardView] Loaded cardId: \(cardId)")
            
            // Check if we have a mock card ID and need to create a real card
            if cardId == "mock-card-id" {
                print("[CardView] WARNING: Found mock card ID, clearing it to trigger real card creation")
                UserSettings().strigaCardId = nil
                StrigaSession.shared.cardId = nil
                // This will trigger the NoCardView which can create a real card
            }
        } else {
            print("[CardView] WARNING: No card ID found in UserSettings")
        }
        
        // TODO: Fetch wallet balance from API
        walletBalance = "€0.00"
        isCardFrozen = false
    }
    
    @MainActor
    private func loadRealCardData(authToken: String) async {
        do {
            guard let userId = StrigaSession.shared.userId,
                  let cardId = StrigaSession.shared.cardId else {
                print("[CardView] Missing user or card ID")
                return
            }
            
            print("[CardView] Fetching card details with auth token")
            print("[CardView] Card ID: \(cardId)")
            
            // Fetch card details with auth token
            let cardDetails = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: authToken
            ))
            
            print("[CardView] Card details received")
            
            // Update UI with real card data
            cardHolderName = cardDetails.name
            
            // Format card number with spaces
            if let fullCardNumber = cardDetails.cardNumber {
                // Add spaces every 4 digits
                let cleaned = fullCardNumber.replacingOccurrences(of: " ", with: "")
                var formatted = ""
                for (index, char) in cleaned.enumerated() {
                    if index > 0 && index % 4 == 0 {
                        formatted += " "
                    }
                    formatted += String(char)
                }
                cardNumber = formatted
            } else {
                // Fallback to masked number
                cardNumber = cardDetails.maskedCardNumber
            }
            
            // Format expiry date
            cardExpiry = "\(cardDetails.expiryMonth)/\(String(cardDetails.expiryYear).suffix(2))"
            
            // Set CVV
            cardCVV = cardDetails.cvv ?? "***"
            
            print("[CardView] Card details updated successfully")
            
        } catch {
            print("[CardView] Error loading card details: \(error)")
            if let validationError = error as? ValidationErrorResponse {
                print("[CardView] Validation error: \(validationError.message)")
            }
        }
    }
}

// MARK: - Card detail components

private enum CardTextStyle {
    case label, value, name
    var font: Font {
        switch self {
        case .label: return .custom("Inter", size: 16)
        case .value: return .custom("Inter", size: 16).weight(.semibold)
        case .name:  return .custom("Inter", size: 16).weight(.semibold)
        }
    }
}

private extension Text {
    func cardStyle(_ style: CardTextStyle) -> some View {
        self.font(style.font).foregroundColor(.white)
    }
}

private struct ValueWithCopy: View {
    let text: String
    let style: CardTextStyle
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .cardStyle(style)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
            Button(action: { UIPasteboard.general.string = text }) {
                Image("copy-icon")
                    .resizable()
                    .frame(width: 14, height: 14)
            }
        }
    }
}

private struct CardModel {
    let holder: String
    let number: String
    let expiry: String
    let cvv: String
}

private struct CardMini: View {
    let card: CardModel
    let qrAddress: String
    let onQRTap: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(card.holder).cardStyle(.name)

                Text("Card number").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                ValueWithCopy(text: card.number, style: .value)

                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expiry").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                        ValueWithCopy(text: card.expiry, style: .value)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV").cardStyle(.label).foregroundColor(.white.opacity(0.7))
                        ValueWithCopy(text: card.cvv, style: .value)
                    }
                }
            }
            Spacer(minLength: 12)
            QRCodeImage(text: qrAddress)
                .frame(width: 48, height: 48)
                .onTapGesture { onQRTap() }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color("PrimaryNuriBlack"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .aspectRatio(257/163, contentMode: .fit)
        .frame(minHeight: 196)
    }
}

private struct SmallIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .foregroundColor(Color("PrimaryNuriBlack"))
            }
        }
    }
}

#if DEBUG
#Preview {
    CardViewActive()
}
#endif

// ShareSheet helper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
