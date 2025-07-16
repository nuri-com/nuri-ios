import SwiftUI
import PassKit

struct TopUpCardView: View {

    @Binding var isPresented: Bool
    @State private var exchangeRate: Double = 0 // BTC to EUR rate

    var body: some View {
        AmountEntryScreen(
            title: "Top-Up Card",
            primarySymbol: "€",
            secondarySymbol: "₿",
            initialPrimaryIsCrypto: false,
            exchangeRate: $exchangeRate,
            actionIcon: "bitcoin-circle",
            actionTitle: "Top-Up Card",
            onSubmit: { amount, isCrypto in
                // Handle top-up logic here
                print("Top-up amount: \(amount), isCrypto: \(isCrypto)")
            },
            onClose: {
                isPresented = false
            }
        )
        .task {
            // Fetch BTC to EUR exchange rate
            guard let url = URL(string: "https://mempool.space/api/v1/prices") else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let eur = dict["EUR"] as? Double {
                    await MainActor.run {
                        exchangeRate = eur
                    }
                }
            } catch {
                print("Price fetch failed", error)
            }
        }
    }

}

#Preview {
    NavigationStack {
        TopUpCardView(isPresented: .constant(true))
    }
} 