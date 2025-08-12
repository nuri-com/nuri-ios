import SwiftUI
import StrigaAPI

struct BuySetAmountView: View {
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletState = WalletStateManager.shared
    
    @State private var navigateToConfirm = false
    @State private var btcToEurRate: Double = 0
    @State private var eurBalance: Double = 0
    
    // Amounts to forward to confirmation screen
    @State private var btcAmount: Double = 0
    @State private var eurAmount: Double = 0
    
    private let striga = StrigaService.shared
    
    var body: some View {
        ZStack {
            AmountEntryScreen(
                title: "€ \(String(format: "%.2f", eurBalance)) Balance",
                primarySymbol: "€",
                secondarySymbol: "₿",
                initialPrimaryIsCrypto: false,
                exchangeRate: $btcToEurRate,
                availableBalance: UInt64(eurBalance * 100), // Convert EUR to cents for comparison
                walletState: nil, // No wallet state needed for buy flow
                actionIcon: "money_topup",
                actionTitle: "Confirm Amount",
                onSubmit: { amount, isCrypto in
                    print("🚀 [BuySetAmountView] Amount submission:")
                    print("   💰 Raw amount: \(amount)")
                    print("   🪙 isCrypto: \(isCrypto)")
                    print("   📊 btcToEurRate: \(btcToEurRate)")
                    
                    let btc: Double
                    let eur: Double
                    if isCrypto {
                        // amount is in BTC
                        btc = amount
                        eur = amount * btcToEurRate
                        print("🪙 [BuySetAmountView] BTC PATH:")
                        print("   ₿ BTC: \(btc)")
                        print("   💶 EUR: \(eur)")
                    } else {
                        // amount is in EUR
                        eur = amount
                        btc = amount / btcToEurRate
                        print("💶 [BuySetAmountView] EUR PATH:")
                        print("   💶 EUR: \(eur)")
                        print("   ₿ BTC: \(btc)")
                    }
                    
                    // Store for confirmation screen
                    self.btcAmount = btc
                    self.eurAmount = eur
                    
                    navigateToConfirm = true
                },
                onClose: {
                    navigation.isBuyViewPresented = false
                }
            )
            .task {
                await loadEURBalance()
                await fetchBTCPrice()
            }
            
            NavigationLink(
                destination: BuyConfirmView(btcAmount: btcAmount, eurAmount: eurAmount),
                isActive: $navigateToConfirm
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func loadEURBalance() async {
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                print("❌ [BuySetAmountView] Missing user or card ID")
                return
            }
            
            // Get card to find the linked wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            // Get wallet details
            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
            
            // Get EUR balance
            if let eurAccount = walletResponse.accounts.eur {
                let amount = eurAccount.availableBalance.amount
                if let cents = Double(amount) {
                    let euros = cents / 100.0
                    await MainActor.run {
                        self.eurBalance = euros
                    }
                    print("✅ [BuySetAmountView] EUR balance: €\(euros)")
                }
            }
        } catch {
            print("❌ [BuySetAmountView] Error loading EUR balance: \(error)")
        }
    }
    
    private func fetchBTCPrice() async {
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eur = dict["EUR"] as? Double {
                await MainActor.run {
                    btcToEurRate = eur
                }
                print("📊 [BuySetAmountView] BTC to EUR rate: \(eur)")
            }
        } catch {
            print("❌ [BuySetAmountView] Price fetch failed: \(error)")
        }
    }
}

#Preview {
    BuySetAmountView()
        .environmentObject(BitcoinViewNavigation())
}