import SwiftUI

final class BitcoinViewNavigation: ObservableObject {
    @Published var isSendViewPresented = false
    @Published var isReceiveViewPresented = false
    @Published var isTransactionsPresented = false
    @Published var isBuyBitcoinPresented = false
}

struct BitcoinView: View {

    @StateObject private var navigation = BitcoinViewNavigation()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NuriHeader<AnyView, AnyView>.logoAndCTA(
                    title: "",
                    cta: "+ Buy Bitcoin",
                    onCTA: { navigation.isBuyBitcoinPresented = true }
                )

                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        VStack(spacing: 4) {
                            AmountAndCurrency()
                            SecondaryCurrencyAndAmount()
                        }
                        HStack(spacing: 16) {
                            PrimaryHalfButton(title: "Receive", icon: "bitcoin_hand") {
                                navigation.isReceiveViewPresented = true
                            }
                            SecondaryHalfButton(title: "Send", icon: "qr_scan") {
                                navigation.isSendViewPresented = true
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    Spacer()
                    Button(action: {
                        navigation.isTransactionsPresented = true
                    }) {
                        Image("link-icon-to-transactions")
                            .resizable()
                            .frame(width: 24, height: 13)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
        .background(NuriAsset.background.swiftUIColor)
        .sheet(isPresented: $navigation.isSendViewPresented) {
            NavigationStack {
                SendView()
            }
        }
        .sheet(isPresented: $navigation.isReceiveViewPresented) {
            NavigationStack {
                ReceiveView()
            }
        }
        .sheet(isPresented: $navigation.isBuyBitcoinPresented) {
            NavigationStack {
                BuyBitcoinView(isPresented: $navigation.isBuyBitcoinPresented)
            }
        }
        .environmentObject(navigation)
        .fullScreenCover(isPresented: $navigation.isTransactionsPresented) {
            TransactionsView()
        }
    }
}

private struct AmountAndCurrency: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("bitcoin-recurring")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            HStack(spacing: 10) {
                Text("₿")
                    .font(.brandTitle1)
                HStack(spacing: 0) {
                    Text("0.0000")
                        .foregroundColor(Color.gray.opacity(0.55))
                    Text("1337")
                }
                .font(.brandTitle1)
            }
            Image("transfer_vertical")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
        }
    }
}

private struct SecondaryCurrencyAndAmount: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("€ ")
            Text("11.23")
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(Color(hex: "#6D6D86"))
    }
}

private struct SecondaryHalfButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Color(hex: "#2C232E"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color(hex: "#2C232E"), lineWidth: 1.4)
            )
        }
    }
}

private struct PrimaryHalfButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Color(hex: "#2C232E"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(hex: "#BEAAFF"))
            .cornerRadius(32)
        }
    }
}

#Preview {
    BitcoinView()
} 
