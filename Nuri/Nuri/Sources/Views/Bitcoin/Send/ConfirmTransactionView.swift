import SwiftUI

struct ConfirmTransactionView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation

    var body: some View {
        VStack(spacing: 16) {
            Text("Confirm Transaction")
                .font(.brandTitle1)
                .foregroundColor(Color("PrimaryNuriBlack"))
            HStack(spacing: 8) {
                Text("₿")
                    .font(.system(size: 40, weight: .semibold))
                HStack(spacing: 0) {
                    Text("0.0000")
                        .foregroundColor(Color.gray.opacity(0.55))
                    Text("1337")
                }
                .font(.system(size: 40, weight: .semibold))
            }
            Text("~ 11.23 EUR")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("Recipient")
                Text("bc1q87rj40hdu23kzwyz5aq89fj84wrrf6h757r0y5kpxhnez2q8uvnq0gjqfl")
                Divider()
                HStack {
                    Text("Send")
                    Spacer()
                    Text("0.00001337 BTC")
                }
                HStack {
                    Text("From Bitcoin Wallet")
                    Spacer()
                    Text("11.23 EUR")
                }
                .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("Network Fee")
                    Spacer()
                    Text("0.32 EUR")
                }
                HStack {
                    Spacer()
                    Text("0.0000012 BTC")
                }
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.vertical, 16)

            Spacer()
            NavigationLink("Send") {
                SuccessView(illustration: "bitcoin-sent", title: "Bitcoin sent!", subtitle: "You've sent 0.9123 BTC!") {
                    navigation.isSendViewPresented = false
                }
            }
            .buttonStyle(ProminentButtonStyle())
        }
        .padding(32)
        .background(NuriAsset.background.swiftUIColor)
        .navigationTitle("Send Bitcoin")
    }
}
