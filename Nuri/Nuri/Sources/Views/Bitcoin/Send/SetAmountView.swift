import SwiftUI

struct SetAmountView: View {
    let recipientAddress: String
    
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToConfirm = false
    @State private var satsToEurRate: Double = 0

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
                exchangeRate: satsToEurRate,
                actionIcon: "bitcoin-circle",
                actionTitle: "Confirm Amount",
                onSubmit: { amount, isCrypto in
                    Task {
                        // Fetch latest BTC price to ensure consistency with entry screen
                        let btcToEurRate = await fetchPrice()
                        let safeBtcToEurRate = btcToEurRate > 0 ? btcToEurRate : 1
                        
                        let btc: Double
                        let eur: Double
                        if isCrypto {
                            // amount is in satoshis, convert to BTC for backend compatibility
                            btc = amount / 100_000_000
                            eur = btc * safeBtcToEurRate
                        } else {
                            eur = amount
                            btc = amount / safeBtcToEurRate
                        }
                        await MainActor.run {
                            btcAmount = btc
                            eurAmount = eur
                            navigateToConfirm = true
                        }
                    }
                },
                onClose: {
                    navigation.isSendViewPresented = false
                }
            )
            .task {
                // Calculate sats to EUR rate
                let btcToEurRate = await fetchPrice()
                let satsToEur = btcToEurRate / 100_000_000
                await MainActor.run {
                    satsToEurRate = satsToEur
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
