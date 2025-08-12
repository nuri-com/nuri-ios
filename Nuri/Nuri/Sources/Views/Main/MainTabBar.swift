import SwiftUI
import StrigaAPI

struct MainTabBar: View {
    @State private var selectedTab: SelectedTab = .passkey
    @StateObject private var walletStateManager = WalletStateManager.shared
    @State private var eurBalance: String = "0.00"
    @State private var passkeyCount: Int = 0
    @State private var refreshTimer: Timer?

    enum SelectedTab {
        case bitcoin
        case card
        case passkey
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                Tab(bitcoinTabLabel, image: "bitcoin-icon") {
                    NavigationStack {
                        BitcoinView()
                    }
                }
                Tab(cardTabLabel, image: "vector-icon-card") {
                    NavigationStack {
                        CardView()
                    }
                }
                Tab(keysTabLabel, image: "passkey") {
                    NavigationStack {
                        SecurityView()
                    }
                }
            }
            .accentColor(Color("PrimaryNuriBlack"))
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            loadInitialData()
            startPeriodicRefresh()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }
    
    private var bitcoinTabLabel: String {
        let sats = walletStateManager.balance.total
        return "₿ \(sats)"
    }
    
    private var cardTabLabel: String {
        return "€ \(eurBalance)"
    }
    
    private var keysTabLabel: String {
        return "Keys: \(passkeyCount)"
    }
    
    private func loadInitialData() {
        Task {
            await loadEurBalance()
            await loadPasskeyCount()
        }
    }
    
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { _ in
            Task {
                await loadEurBalance()
                await loadPasskeyCount()
            }
        }
    }
    
    @MainActor
    private func loadEurBalance() async {
        guard let userId = UserSettings().strigaUserId else {
            eurBalance = "0.00"
            return
        }
        
        do {
            let walletsResponse = try await StrigaService.shared.getWallets(userId: userId)
            
            if let firstWallet = walletsResponse.wallets.first,
               let eurAccount = firstWallet.accounts.eur {
                let balanceInCents = eurAccount.availableBalance.amount
                let balanceInEuros = (Double(balanceInCents) ?? 0.0) / 100.0
                eurBalance = String(format: "%.2f", balanceInEuros)
            } else {
                eurBalance = "0.00"
            }
        } catch {
            print("[MainTabBar] Failed to load EUR balance: \(error)")
            eurBalance = "0.00"
        }
    }
    
    @MainActor
    private func loadPasskeyCount() async {
        guard let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
            // If user is logged in but we can't get username, assume at least 1 passkey
            passkeyCount = isUserLoggedIn() ? 1 : 0
            return
        }
        
        do {
            let passkeys = try await PasskeyAuthenticationService.shared.getUserPasskeys(for: username)
            passkeyCount = max(passkeys.count, 1) // Always show at least 1 if logged in
        } catch {
            print("[MainTabBar] Failed to load passkey count: \(error)")
            // If there's an error but user is logged in, they must have at least 1 passkey
            passkeyCount = isUserLoggedIn() ? 1 : 0
        }
    }
    
    private func isUserLoggedIn() -> Bool {
        return UserDefaults.standard.bool(forKey: "isUserLoggedIn")
    }
}

#Preview {
    MainTabBar()
}
