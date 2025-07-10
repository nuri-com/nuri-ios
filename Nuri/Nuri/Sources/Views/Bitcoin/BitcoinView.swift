import SwiftUI

final class BitcoinViewNavigation: ObservableObject {
    @Published var isSendViewPresented = false
    @Published var isReceiveViewPresented = false
    @Published var isTransactionsPresented = false
    @Published var isBuyBitcoinPresented = false
}

struct BitcoinView: View {

    @StateObject private var navigation = BitcoinViewNavigation()
    @State private var isPrimaryBTC = true
    @State private var isBalanceHidden = false
    @State private var walletStatus: WalletStatus = .checking
    @State private var showWalletRecoveryAlert = false
    @State private var balanceSats: UInt64 = 0
    @State private var exchangeRate: Double = 0.0
    
    enum WalletStatus {
        case checking
        case loaded
        case needsRecovery
        case failed
    }

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
                            AmountAndCurrency(isPrimaryBTC: $isPrimaryBTC,
                                             isBalanceHidden: $isBalanceHidden,
                                             sats: balanceSats,
                                             rate: exchangeRate)
                            SecondaryCurrencyAndAmount(isPrimaryBTC: $isPrimaryBTC,
                                                       isBalanceHidden: $isBalanceHidden,
                                                       sats: balanceSats,
                                                       rate: exchangeRate)
                        }
                        .onTapGesture {
                            isBalanceHidden.toggle()
                        }
                        HStack(spacing: 16) {
                            PrimaryHalfButton(title: "Receive", icon: "bitcoin_hand") {
                                ensureWalletInitialized {
                                    navigation.isReceiveViewPresented = true
                                }
                            }
                            SecondaryHalfButton(title: "Send", icon: "qr_scan") {
                                ensureWalletInitialized {
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
        .onAppear {
            // Don't automatically check wallet status
        }
        .task {
            await refreshBalance()
        }
        .alert("Wallet Recovery", isPresented: $showWalletRecoveryAlert) {
            Button("Retry") {
                retryWalletLoad()
            }
            Button("Create New Wallet") {
                createNewWallet()
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
    }
    
    // MARK: - Wallet Management
    private func ensureWalletInitialized(completion: @escaping () -> Void) {
        let walletService = BitcoinWalletService.shared
        
        print("🔍 [BitcoinView] ensureWalletInitialized() called")
        
        // Check if wallet is already initialized
        if walletService.hasWallet() {
            print("✅ [BitcoinView] Wallet already initialized, no Face ID needed")
            walletStatus = .loaded
            completion()
            return
        }
        
        // Initialize wallet with default user - should already be done by app start
        print("🔑 [BitcoinView] 🚨 WALLET RE-INITIALIZATION - This should NOT happen if wallet was already loaded!")
        print("🔑 [BitcoinView] Initializing wallet with default user")
        walletStatus = .checking
        
        walletService.initializeWalletOnAppStart()
        
        // Check if initialization was successful
        if walletService.hasWallet() {
            walletStatus = .loaded
            completion()
        } else {
            walletStatus = .needsRecovery
            showWalletRecoveryAlert = true
        }
    }
    
    private func checkWalletStatus() {
        // Keep this method for manual retry scenarios
        ensureWalletInitialized {
            // Wallet is ready
        }
    }
    
    private func retryWalletLoad() {
        walletStatus = .checking
        
        // Re-initialize wallet with default user
        let walletService = BitcoinWalletService.shared
        walletService.initializeWalletOnAppStart()
        
        // Check status after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if walletService.hasWallet() {
                walletStatus = .loaded
            } else {
                walletStatus = .needsRecovery
                showWalletRecoveryAlert = true
            }
        }
    }
    
    private func createNewWallet() {
        walletStatus = .checking
        
        let walletService = BitcoinWalletService.shared
        walletService.initializeWalletOnAppStart()
        walletService.forceCreateNewWallet()
        
        // Check status after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if walletService.hasWallet() {
                walletStatus = .loaded
            } else {
                walletStatus = .failed
            }
        }
    }

    // MARK: - Balance
    private func refreshBalance() async {
        let walletService = BitcoinWalletService.shared
        if let sats = await walletService.syncAndGetBalance() {
            await MainActor.run { balanceSats = sats }
        } else {
            await MainActor.run { balanceSats = 0 }
        }

        if let price = await fetchPrice() {
            await MainActor.run { exchangeRate = price }
        }
    }

    private func fetchPrice() async -> Double? {
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let eur = dict["EUR"] as? Double {
                return eur
            }
        } catch {
            print("Price fetch failed", error)
        }
        return nil
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
                let eurString = String(format: "%.2f", btc * rate)
                let satsString = String(sats)
                HStack(spacing: 0) {
                    if isPrimaryBTC {
                        Text("€ ")
                        Text(eurString)
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
