import SwiftUI

struct SetAmountView: View {
    let recipientAddress: String
    
    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToConfirm = false

    // Amounts to forward to confirmation screen
    @State private var btcAmount: Double = 0
    @State private var eurAmount: Double = 0

    var body: some View {
        ZStack {
            AmountEntryScreen(
                title: "Confirm Amount",
                primarySymbol: "₿",
                secondarySymbol: "€",
                initialPrimaryIsCrypto: true,
                exchangeRate: 0, // will be fetched inside the component; we'll refetch before navigating
                actionIcon: "bitcoin-circle",
                actionTitle: "Confirm Amount",
                onSubmit: { amount, isCrypto in
                    Task {
                        // Fetch latest BTC price to ensure consistency with entry screen
                        let rate = await fetchPrice()
                        let safeRate = rate > 0 ? rate : 1
                        let btc: Double
                        let eur: Double
                        if isCrypto {
                            btc = amount
                            eur = amount * safeRate
                        } else {
                            eur = amount
                            btc = amount / safeRate
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
