import SwiftUI

struct SetAmountView: View {
    let recipientAddress: String
    
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToConfirm = false
    @State private var satsToEurRate: Double = 0
    @State private var btcToEurRate: Double = 0

    // Amounts to forward to confirmation screen  
    @State private var btcAmount: Double = 0 // Still in BTC for compatibility with ConfirmTransactionView
    @State private var eurAmount: Double = 0

    var body: some View {
        ZStack {
            AmountEntryScreen(
                title: "Confirm Amount",
                primarySymbol: "₿",
                secondarySymbol: "€",
                initialPrimaryIsCrypto: true,
                exchangeRate: $satsToEurRate,
                actionIcon: "bitcoin-circle",
                actionTitle: "Confirm Amount",
                onSubmit: { amount, isCrypto in
                    print("💰 [SetAmountView] onSubmit called with amount: \(amount), isCrypto: \(isCrypto)")
                    
                    let btc: Double
                    let eur: Double
                    if isCrypto {
                        // amount is in satoshis - use the current rates we have
                        let satsAmount = amount
                        btc = satsAmount / 100_000_000
                        eur = satsAmount * satsToEurRate
                        print("💰 [SetAmountView] Sats: \(satsAmount), BTC: \(btc), EUR: \(eur)")
                    } else {
                        // amount is in EUR
                        eur = amount
                        let satsAmount = amount / satsToEurRate
                        btc = satsAmount / 100_000_000
                        print("💰 [SetAmountView] EUR: \(eur), Sats: \(satsAmount), BTC: \(btc)")
                    }
                    
                    btcAmount = btc
                    eurAmount = eur
                    navigateToConfirm = true
                },
                onClose: {
                    navigation.isSendViewPresented = false
                }
            )
            .task {
                // Fetch BTC price and calculate sats rate
                print("🔄 [SetAmountView] Fetching exchange rates...")
                let fetchedBtcToEurRate = await fetchPrice()
                let calculatedSatsToEurRate = fetchedBtcToEurRate / 100_000_000
                
                print("📊 [SetAmountView] BTC to EUR rate: \(fetchedBtcToEurRate)")
                print("📊 [SetAmountView] Sats to EUR rate: \(calculatedSatsToEurRate)")
                
                await MainActor.run {
                    btcToEurRate = fetchedBtcToEurRate
                    satsToEurRate = calculatedSatsToEurRate
                }
            }

            NavigationLink(destination: ConfirmTransactionView(btcAmount: btcAmount, eurAmount: eurAmount, recipientAddress: recipientAddress), isActive: $navigateToConfirm) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers
    private func fetchPrice() async -> Double {
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { return 0 }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any], let eur = dict["EUR"] as? Double {
                return eur
            }
        } catch {
            print("Price fetch failed", error)
        }
        return 0
    }
}
