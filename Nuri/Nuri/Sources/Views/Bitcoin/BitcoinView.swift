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
                            AmountAndCurrency(isPrimaryBTC: $isPrimaryBTC, isBalanceHidden: $isBalanceHidden)
                            SecondaryCurrencyAndAmount(isPrimaryBTC: $isPrimaryBTC, isBalanceHidden: $isBalanceHidden)
                        }
                        .onTapGesture {
                            isBalanceHidden.toggle()
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
        .onAppear {
            checkWalletStatus()
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
    private func checkWalletStatus() {
        let walletService = BitcoinWalletService.shared
        
        // Check if wallet is already initialized
        if walletService.hasWallet() {
            walletStatus = .loaded
            return
        }
        
        // Try to initialize wallet with stored user ID
        let tokens = PasskeyService.getStoredTokens()
        if let userID = tokens.2 {
            print("🔑 [BitcoinView] Initializing wallet for user: \(userID)")
            walletService.initializeForUser(userID)
            
            // Check if initialization was successful
            if walletService.hasWallet() {
                walletStatus = .loaded
            } else {
                walletStatus = .needsRecovery
                // Give user a moment to see the view before showing alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showWalletRecoveryAlert = true
                }
            }
        } else {
            print("⚠️ [BitcoinView] No user ID found - wallet cannot be initialized")
            walletStatus = .failed
        }
    }
    
    private func retryWalletLoad() {
        walletStatus = .checking
        
        // Re-initialize wallet with user ID
        let tokens = PasskeyService.getStoredTokens()
        if let userID = tokens.2 {
            let walletService = BitcoinWalletService.shared
            walletService.initializeForUser(userID)
            
            // Check status after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if walletService.hasWallet() {
                    walletStatus = .loaded
                } else {
                    walletStatus = .needsRecovery
                    showWalletRecoveryAlert = true
                }
            }
        } else {
            walletStatus = .failed
        }
    }
    
    private func createNewWallet() {
        walletStatus = .checking
        
        let tokens = PasskeyService.getStoredTokens()
        if let userID = tokens.2 {
            let walletService = BitcoinWalletService.shared
            walletService.initializeForUser(userID)
            walletService.forceCreateNewWallet()
            
            // Check status after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if walletService.hasWallet() {
                    walletStatus = .loaded
                } else {
                    walletStatus = .failed
                }
            }
        } else {
            walletStatus = .failed
        }
    }
}

private struct AmountAndCurrency: View {
    @Binding var isPrimaryBTC: Bool
    @Binding var isBalanceHidden: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isBalanceHidden {
                Text("********")
                    .font(.brandTitle1)
            } else {
                HStack(spacing: 10) {
                    if isPrimaryBTC {
                        Text("₿")
                        HStack(spacing: 0) {
                            Text("0.0000")
                                .foregroundColor(Color.gray.opacity(0.55))
                            Text("1337")
                        }
                    } else {
                        HStack(spacing: 0) {
                            Text("€ ")
                            Text("11.23")
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

    var body: some View {
        Group {
            if isBalanceHidden {
                Text("********")
            } else {
                HStack(spacing: 0) {
                    if isPrimaryBTC {
                        Text("€ ")
                        Text("11.23")
                    } else {
                        Text("₿ 0.00001337")
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
