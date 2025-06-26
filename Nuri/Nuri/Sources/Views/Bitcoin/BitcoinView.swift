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
            VStack {
                Spacer()
                VStack(spacing: 21) {
                    VStack(spacing: 12) {
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
                    .padding(.vertical, 24)
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
            .padding(.top, 44)
            .padding(.bottom, 34)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image("nuri-logo-svg")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigation.isBuyBitcoinPresented = true
                } label: {
                    Text("+ Buy Bitcoin")
                        .font(.custom("Inter", size: 14).weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("PrimaryNuriBlack"))
                        .cornerRadius(64)
                }
            }
        }
    }
}

private struct AmountAndCurrency: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("₿")
                .font(.system(size: 40, weight: .semibold))
            HStack(spacing: 0) {
                Text("0.0000")
                    .foregroundColor(Color.gray.opacity(0.55))
                Text("1337")
            }
            .font(.system(size: 40, weight: .semibold))
        }
    }
}

private struct SecondaryCurrencyAndAmount: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("€")
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
