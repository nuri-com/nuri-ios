import SwiftUI

struct ConfirmTransactionView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    // Dummy values – these will later be provided via constructor
    private let btcAmount: Double = 0.00001337
    private let eurAmount: Double = 11.23
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
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)

                // Details card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient")
                        .font(.brandBody)
                    Text(recipient)
                        .font(.system(size: 14, weight: .medium))
                        .textSelection(.enabled)
                    Divider()
                    HStack {
                        Text("Send")
                        Spacer()
                        Text(String(format: "%0.8f BTC", btcAmount))
                    }
                    HStack {
                        Text("From Bitcoin Wallet")
                        Spacer()
                        Text(String(format: "%.2f EUR", eurAmount))
                    }
                    .foregroundStyle(.secondary)
                    Divider()
                    HStack {
                        Text("Network Fee")
                        Spacer()
                        Text(String(format: "%.2f EUR", networkFeeEur))
                    }
                    HStack {
                        Spacer()
                        Text(String(format: "%0.8f BTC", networkFeeBtc))
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.vertical, 16)

                Spacer()

                NavigationLink(destination: SuccessView(illustration: "bitcoin-sent", title: "Bitcoin sent!", subtitle: "You've sent 0.9123 BTC!") {
                    navigation.isSendViewPresented = false
                }) {
                    NuriButton(icon: "bitcoin-circle", title: "Send", style: .primary)
                }
            }
            .padding(32)
        }
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
