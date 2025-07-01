import SwiftUI

struct ConfirmTransactionView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    // Values provided by previous screen
    let btcAmount: Double
    let eurAmount: Double

    // TODO: These could be provided/calculated later.
    private let networkFeeEur: Double = 0.32
    private let networkFeeBtc: Double = 0.0000012
    private let recipient: String = "bc1q87rj40hdu23kzwyz5aq89fj84wrrf6h757r0y5kpxhnez2q8uvnq0gjqfl"

    var body: some View {
        Screen {
            NuriHeader<AnyView, AnyView>.backAndClose(
                title: "Confirm Transaction",
                onBack: { dismiss() },
                onClose: { navigation.isSendViewPresented = false }
            )
        } content: {
            VStack(spacing: 16) {
                // Amount
                HStack(spacing: 8) {
                    Text("₿")
                        .font(.system(size: 40, weight: .semibold))
                    Text(String(format: "%0.8f", btcAmount).trimTrailingZeros())
                        .font(.system(size: 40, weight: .semibold))
                }
                Text(String(format: "~ %.2f EUR", eurAmount))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.secondary)

                // Details card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient")
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundColor(Color("PrimaryNuriBlack"))
                    recipientView()
                    Divider()
                    HStack {
                        Text("Send")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                        Text(String(format: "%0.8f BTC", btcAmount))
                            .font(.custom("Inter", size: 16).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    HStack {
                        Text("From Bitcoin Wallet")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("TextSecondary"))
                        Spacer()
                        Text(String(format: "%.2f EUR", eurAmount))
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    Divider()
                    HStack {
                        Text("Network Fee")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                        Text(String(format: "%.2f EUR", networkFeeEur))
                            .font(.custom("Inter", size: 16).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    HStack {
                        Spacer()
                        Text(String(format: "%0.8f BTC", networkFeeBtc))
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(Color("TextSecondary"))
                    }
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.vertical, 16)

                Spacer()

                NavigationLink(destination: SuccessView(illustration: "bitcoin-sent", title: "Bitcoin sent!", subtitle: "You've sent \(formattedBtc) BTC!", onDone: {
                    navigation.isSendViewPresented = false
                })) {
                    NuriButton(icon: "bitcoin-circle", title: "Send", style: .primary)
                }
            }
            .padding(32)
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func recipientView() -> some View {
        let segments = segmentedRecipient()
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { idx in
                let seg = segments[idx]
                Text(seg)
                    .font(.custom("Inter", size: 16).weight(idx % 2 == 0 ? .semibold : .regular))
                    .foregroundColor(idx % 2 == 0 ? Color("PrimaryNuriBlack") : Color("TextSecondary"))
            }
        }
        .textSelection(.enabled)
    }

    private func segmentedRecipient() -> [String] {
        stride(from: 0, to: recipient.count, by: 5).map { start in
            let end = min(start + 5, recipient.count)
            let startIdx = recipient.index(recipient.startIndex, offsetBy: start)
            let endIdx = recipient.index(recipient.startIndex, offsetBy: end)
            return String(recipient[startIdx..<endIdx])
        }
    }

    private var formattedBtc: String {
        String(format: "%0.8f", btcAmount).trimTrailingZeros()
    }
}

private extension String {
    /// Removes trailing zeros from a decimal string ("0.10000000" -> "0.1").
    func trimTrailingZeros() -> String {
        var s = self
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return s
    }
}
