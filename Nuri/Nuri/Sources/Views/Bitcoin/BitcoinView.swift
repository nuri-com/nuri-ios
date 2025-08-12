import SwiftUI

final class BitcoinViewNavigation: ObservableObject {
    @Published var isSendViewPresented = false
    @Published var isReceiveViewPresented = false
    @Published var isTransactionsPresented = false
    @Published var isBuyBitcoinPresented = false
}

struct BitcoinView: View {

    @StateObject private var navigation = BitcoinViewNavigation()
    @StateObject private var viewModel = BitcoinViewModel()
    
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
                            AmountAndCurrency(isPrimaryBTC: $viewModel.isPrimaryBTC,
                                             isBalanceHidden: $viewModel.isBalanceHidden,
                                             sats: viewModel.balance.confirmed,
                                             rate: viewModel.exchangeRate)
                            SecondaryCurrencyAndAmount(isPrimaryBTC: $viewModel.isPrimaryBTC,
                                                       isBalanceHidden: $viewModel.isBalanceHidden,
                                                       sats: viewModel.balance.confirmed,
                                                       rate: viewModel.exchangeRate)
                        }
                        .onTapGesture {
                            viewModel.isBalanceHidden.toggle()
                        }
                        HStack(spacing: 16) {
                            PrimaryHalfButton(title: "Receive", icon: "bitcoin_hand") {
                                // Just open receive view directly without authentication
                                navigation.isReceiveViewPresented = true
                            }
                            SecondaryHalfButton(title: "Send", icon: "qr_scan") {
                                viewModel.onSendButtonTapped {
                                    navigation.isSendViewPresented = true
                                }
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
        .onDisappear {
            print("⏰ [BitcoinView] View disappeared")
        }
        .task {
            await viewModel.onTask()
        }
        .alert("Wallet Recovery", isPresented: $viewModel.showWalletRecoveryAlert) {
            Button("Retry") {
                viewModel.onRetryWalletLoad()
            }
            Button("Create New Wallet") {
                viewModel.onCreateNewWallet()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your Bitcoin wallet needs to be recovered. Would you like to retry loading your existing wallet or create a new one?")
        }
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
        .onAppear {
            viewModel.onAppear()
        }
    }
}

private struct AmountAndCurrency: View {
    @Binding var isPrimaryBTC: Bool
    @Binding var isBalanceHidden: Bool
    var sats: UInt64
    var rate: Double

    var body: some View {
        let btc = Double(sats) / 100_000_000
        let eurString = String(format: "%.2f", btc * rate)
        let satsString = String(sats)

        HStack(spacing: 8) {
            if isBalanceHidden {
                Text("********")
                    .font(.brandTitle1)
            } else {
                HStack(spacing: 10) {
                    if isPrimaryBTC {
                        HStack(spacing: 4) {
                            Text("₿")
                            Text(satsString)
                        }
                    } else {
                        HStack(spacing: 0) {
                            Text("€ ")
                            Text(eurString)
                        }
                    }
                }
                .font(.brandTitle1)
            }

            Button(action: { isPrimaryBTC.toggle() }) {
                Image("transfer_vertical")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SecondaryCurrencyAndAmount: View {
    @Binding var isPrimaryBTC: Bool
    @Binding var isBalanceHidden: Bool
    var sats: UInt64
    var rate: Double

    var body: some View {
        Group {
            if isBalanceHidden {
                Text("********")
            } else {
                let btc = Double(sats) / 100_000_000
                let eurString = rate > 0 ? String(format: "%.2f", btc * rate) : "—"
                let satsString = String(sats)
                HStack(spacing: 0) {
                    if isPrimaryBTC {
                        if rate > 0 {
                            Text("€ ")
                            Text(eurString)
                        } else {
                            Text("€ —")
                        }
                    } else {
                        Text("₿ \(satsString)")
                    }
                }
            }
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(Color("PrimaryNuriBlack"))
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
            .foregroundColor(Color("PrimaryNuriBlack"))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color("PrimaryNuriBlack"), lineWidth: 1.4)
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
            .foregroundColor(Color("PrimaryNuriBlack"))
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