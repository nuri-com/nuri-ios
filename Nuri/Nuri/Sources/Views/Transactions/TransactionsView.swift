import SwiftUI

struct TransactionsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Sample Data (Matches Figma "transactions-v3" frame)
    private let transactions: [Transaction] = [
        .init(type: .send,    title: "Send Bitcoin",    btc: -0.053,    fiat: -1_000, date: "Nov 27"),
        .init(type: .card,    title: "Card Spend",      btc: nil,       fiat:  -10.53, date: "Nov 27"),
        .init(type: .receive, title: "Card Top-Up",     btc: nil,       fiat:   100,   date: "Nov 27"),
        .init(type: .send,    title: "Send Bitcoin",    btc: -0.001,   fiat:  -100,   date: "Nov 27"),
        .init(type: .receive, title: "Bought Bitcoin",  btc: 0.001337,  fiat:   133,   date: "Nov 27")
    ]

    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 44) // Status-bar + custom spacing
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .padding(.bottom, 28) // Space between header & first row

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

    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image("vector-back-arrow")
                    .resizable()
                    .frame(width: 24, height: 10)
            }
            .frame(width: 70, alignment: .leading) // Guarantees centred title

            Spacer(minLength: 0)

            Text("Transactions")
                .font(.custom("Inter", size: 16).weight(.semibold))
                .foregroundColor(Color("PrimaryNuriBlack"))

            Spacer(minLength: 0)

            Button(action: { dismiss() }) {
                Image("delete-close")
                    .resizable()
                    .frame(width: 32, height: 32)
            }
            .frame(width: 70, alignment: .trailing)
        }
    }
}

// MARK: - Row
private struct TransactionRow: View {
    let tx: Transaction

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(tx.type.iconName)
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
                if let btc = tx.btc {
                    btcText(btc: btc)
                }

                if let fiat = tx.fiat {
                    fiatText(fiat: fiat, hasBTC: tx.btc != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
    }

    // MARK: - Helpers
    private func btcText(btc: Double) -> Text {
        let isPositive = btc > 0
        let color: Color = isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack")

        let absValue = abs(btc)
        // If the amount is less than 0.01 BTC, split the string per Figma spec
        if absValue < 0.01 {
            let greyPart = Text(isPositive ? "0.00" : "-0.00")
                .foregroundColor(Color("PrimaryNuriBlack").opacity(0.3))
                .font(.custom("Inter", size: 16).weight(.medium))

            // Convert to satoshis (8-decimals) and zero-pad to 6 digits so that
            // the combined string always shows the full 8-decimal BTC value.
            let suffixValue = Int(absValue * 100_000_000)
            let suffixString = String(format: "%06d", suffixValue) // e.g. 42 -> "000042"
            let suffix = Text("\(suffixString) BTC")
                .foregroundColor(color)
                .font(.custom("Inter", size: 16).weight(.medium))

            return greyPart + suffix
        } else {
            return Text(String(format: "%@%.3f BTC", isPositive ? "" : "-", absValue))
                .foregroundColor(color)
                .font(.custom("Inter", size: 16).weight(.medium))
        }
    }

    private func fiatText(fiat: Double, hasBTC: Bool) -> Text {
        let isPositive = fiat > 0

        if hasBTC {
            // Secondary fiat line under BTC amount
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
    enum TxType { case send, receive, card
        var iconName: String {
            switch self {
            case .send:    return "tx-out-icon"
            case .receive: return "tx-in-icon"
            case .card:    return "vector-icon-card"
            }
        }
    }

    let id = UUID()
    let type: TxType
    let title: String
    let btc: Double?
    let fiat: Double?
    let date: String
}

// MARK: - Previews
#if DEBUG
#Preview {
    TransactionsView()
}
#endif 