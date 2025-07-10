import SwiftUI

struct TransactionsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Sample Data (Matches Figma "transactions-v3" frame) - Updated to use satoshis
    private let transactions: [Transaction] = [
        .init(iconName: "list-item-icon-paperplane_send", title: "Send Bitcoin",    sats: -5_300_000,    fiat: -1_000, date: "Nov 27"),
        .init(iconName: "vector-icon-card",             title: "Card Spend",      sats: nil,          fiat:  -10.53, date: "Nov 27"),
        .init(iconName: "money_topup",                   title: "Card Top-Up",     sats: nil,          fiat:   100,   date: "Nov 27"),
        .init(iconName: "list-item-icon-paperplane_send", title: "Send Bitcoin",    sats: -100_000,     fiat:  -100,   date: "Nov 27"),
        .init(iconName: "bitcoin_hand",                  title: "Bought Bitcoin",  sats: 133_700,      fiat:   133,   date: "Nov 27")
    ]

    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()

            VStack(spacing: 0) {
                NuriHeader<AnyView, AnyView>.logo(title: "Transactions", onClose: { dismiss() })

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(transactions.enumerated()), id: \.offset) { index, tx in
                            TransactionRow(tx: tx)

                            if index != transactions.count - 1 {
                                Color.clear.frame(height: 8)             // Top gutter (8 pt)
                                Color(hex: "#E0E0E0").frame(height: 1)  // Divider (1 pt)
                                Color.clear.frame(height: 8)             // Bottom gutter (8 pt)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Row
private struct TransactionRow: View {
    let tx: Transaction

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(tx.iconName)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 0) {
                Text(tx.title)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .font(.custom("Inter", size: 16).weight(.medium))
                Text(tx.date)
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .tracking(-0.25)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                if let sats = tx.sats {
                    satsText(sats: sats)
                }

                if let fiat = tx.fiat {
                    fiatText(fiat: fiat, hasSats: tx.sats != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
    }

    // MARK: - Helpers
    private func satsText(sats: Int64) -> Text {
        let isPositive = sats > 0
        let color: Color = isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack")

        return Text("\(isPositive ? "" : "-")₿\(abs(sats))")
            .foregroundColor(color)
            .font(.custom("Inter", size: 16).weight(.medium))
    }

    private func fiatText(fiat: Double, hasSats: Bool) -> Text {
        let isPositive = fiat > 0

        if hasSats {
            // Secondary fiat line under sats amount
            return Text(String(format: "%@%.0f €", isPositive ? "" : "-", abs(fiat)))
                .foregroundColor(Color(hex: "#6D6D86"))
                .font(.custom("Inter", size: 14).weight(.medium))
                .tracking(-0.25)
        } else {
            // Single-line amount for card rows
            let color: Color = isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack")
            return Text(String(format: "%@%.2f EUR", isPositive ? "" : "-", abs(fiat)))
                .foregroundColor(color)
                .font(.custom("Inter", size: 16).weight(.medium))
        }
    }
}

// MARK: - Model
private struct Transaction: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let sats: Int64?
    let fiat: Double?
    let date: String
}

// MARK: - Previews
#if DEBUG
#Preview {
    TransactionsView()
}
#endif 
