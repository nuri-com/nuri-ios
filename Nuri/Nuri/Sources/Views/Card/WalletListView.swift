import SwiftUI
import StrigaAPI

struct WalletListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wallets: [WalletItem] = []
    @State private var isLoading = true
    @State private var eurAccountId = ""
    
    private let striga = StrigaService.shared
    
    struct WalletItem {
        let currency: String
        let iconName: String
        let address: String
        let accountId: String
        let isIBAN: Bool
        
        var displayAddress: String {
            if isIBAN {
                return address // IBAN format
            } else {
                return address // Blockchain address
            }
        }
        
        var copyText: String {
            return address
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - same design as TransactionsView
                NuriHeader<AnyView, AnyView>.logo(title: "Top-Up Wallets", onClose: { dismiss() })
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if isLoading {
                            // Loading state
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Loading wallets...")
                                    .font(.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                            }
                            .padding(.top, 40)
                        } else if wallets.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "wallet.pass")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                                Text("No wallets available")
                                    .font(.custom("Inter", size: 18).weight(.medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            }
                            .padding(.top, 40)
                        } else {
                            // Wallet list
                            ForEach(Array(wallets.enumerated()), id: \.offset) { index, wallet in
                                WalletRow(wallet: wallet) {
                                    // Copy address when tapped
                                    UIPasteboard.general.string = wallet.copyText
                                    print("📋 Copied \(wallet.currency) address: \(wallet.copyText)")
                                }
                                
                                if index != wallets.count - 1 {
                                    Color.clear.frame(height: 8)             // Top gutter (8 pt)
                                    Color(hex: "#E0E0E0").frame(height: 1)  // Divider (1 pt)
                                    Color.clear.frame(height: 8)             // Bottom gutter (8 pt)
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .task {
            await loadWallets()
        }
    }
    
    private func loadWallets() async {
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                print("❌ [WalletListView] Missing user or card ID")
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            print("🔄 [WalletListView] Loading wallets...")
            
            // Get card to find the linked wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            // Get wallet details
            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
            
            var loadedWallets: [WalletItem] = []
            
            // 1. IBAN (EUR account)
            if let eurAccount = walletResponse.accounts.eur,
               let bankingDetails = eurAccount.bankingDetails {
                
                await MainActor.run {
                    self.eurAccountId = eurAccount.accountId
                }
                
                loadedWallets.append(WalletItem(
                    currency: "EUR / IBAN",
                    iconName: "vector-icon-card",
                    address: bankingDetails.iban,
                    accountId: eurAccount.accountId,
                    isIBAN: true
                ))
            }
            
            // 2. Bitcoin
            if let btcAccount = walletResponse.accounts.btc {
                let btcAddress = await enrichAndGetAddress(account: btcAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "Bitcoin",
                    iconName: "bitcoin-icon",
                    address: btcAddress.isEmpty ? "Loading..." : btcAddress,
                    accountId: btcAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 3. USDC (ERC20 and possibly other networks)
            if let usdcAccount = walletResponse.accounts.usdc {
                // For multi-network support, we need to enrich first
                let enrichedAddresses = await enrichAndGetMultipleAddresses(account: usdcAccount, userId: userId)
                if !enrichedAddresses.isEmpty {
                    for (network, address) in enrichedAddresses {
                        // Default to ERC20 if no specific network specified
                        let networkLabel = network.isEmpty ? "ERC20" : network
                        loadedWallets.append(WalletItem(
                            currency: "USDC (\(networkLabel))",
                            iconName: "usdc-icon",
                            address: address,
                            accountId: usdcAccount.accountId,
                            isIBAN: false
                        ))
                    }
                } else {
                    // Show even if not enriched yet
                    loadedWallets.append(WalletItem(
                        currency: "USDC (ERC20)",
                        iconName: "usdc-icon",
                        address: "Loading...",
                        accountId: usdcAccount.accountId,
                        isIBAN: false
                    ))
                }
            }
            
            // 4. ETH
            if let ethAccount = walletResponse.accounts.eth {
                let ethAddress = await enrichAndGetAddress(account: ethAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "Ethereum",
                    iconName: "eth-icon",
                    address: ethAddress.isEmpty ? "Loading..." : ethAddress,
                    accountId: ethAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 5. BNB (BSC)
            if let bnbAccount = walletResponse.accounts.bnb {
                let bnbAddress = await enrichAndGetAddress(account: bnbAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "BNB (BSC)",
                    iconName: "bnb-icon",
                    address: bnbAddress.isEmpty ? "Loading..." : bnbAddress,
                    accountId: bnbAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 6. POL (Polygon/ERC20)
            if let polAccount = walletResponse.accounts.pol {
                let polAddresses = await enrichAndGetMultipleAddresses(account: polAccount, userId: userId)
                if !polAddresses.isEmpty {
                    for (network, address) in polAddresses {
                        // POL can be on Ethereum (ERC20) or Polygon network
                        let networkLabel = network.isEmpty ? "Polygon" : network
                        loadedWallets.append(WalletItem(
                            currency: "POL (\(networkLabel))",
                            iconName: "pol-icon",
                            address: address,
                            accountId: polAccount.accountId,
                            isIBAN: false
                        ))
                    }
                } else {
                    loadedWallets.append(WalletItem(
                        currency: "POL (Polygon)",
                        iconName: "pol-icon",
                        address: "Loading...",
                        accountId: polAccount.accountId,
                        isIBAN: false
                    ))
                }
            }
            
            // 7. SOL (Solana)
            if let solAccount = walletResponse.accounts.sol {
                let solAddress = await enrichAndGetAddress(account: solAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "SOL",
                    iconName: "sol-icon",
                    address: solAddress.isEmpty ? "Loading..." : solAddress,
                    accountId: solAccount.accountId,
                    isIBAN: false
                ))
            }
            
            // 8. USDT (ERC20)
            if let usdtAccount = walletResponse.accounts.usdt {
                let usdtAddress = await enrichAndGetAddress(account: usdtAccount, userId: userId)
                loadedWallets.append(WalletItem(
                    currency: "USDT (ERC20)",
                    iconName: "usdt-icon",
                    address: usdtAddress.isEmpty ? "Loading..." : usdtAddress,
                    accountId: usdtAccount.accountId,
                    isIBAN: false
                ))
            }
            
            await MainActor.run {
                self.wallets = loadedWallets
                self.isLoading = false
            }
            
            print("✅ [WalletListView] Loaded \(loadedWallets.count) wallets")
            
            // Start monitoring for incoming transactions
            startMonitoringForAutoConversion()
            
        } catch {
            print("❌ [WalletListView] Error loading wallets: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func enrichAndGetAddress(account: CreateWalletResponse.Account, userId: String) async -> String {
        // Check if address already exists
        if let address = account.blockchainDepositAddress, !address.isEmpty {
            return address
        }
        
        // Need to enrich the account
        do {
            print("🔄 [WalletListView] Enriching \(account.currency) account: \(account.accountId)")
            let enrichResponse = try await striga.enrichAccount(
                EnrichAccount(accountId: account.accountId, userId: userId)
            )
            
            if let address = enrichResponse.blockchainDepositAddress {
                print("✅ [WalletListView] Got \(account.currency) address: \(address)")
                return address
            } else if let networks = enrichResponse.blockchainNetworks, !networks.isEmpty {
                let address = networks[0].blockchainDepositAddress
                print("✅ [WalletListView] Got \(account.currency) address from network: \(address)")
                return address
            }
        } catch {
            print("❌ [WalletListView] Error enriching \(account.currency): \(error)")
        }
        
        return ""
    }
    
    private func enrichAndGetMultipleAddresses(account: CreateWalletResponse.Account, userId: String) async -> [(network: String, address: String)] {
        var addresses: [(network: String, address: String)] = []
        
        // Check if address already exists
        if let address = account.blockchainDepositAddress, !address.isEmpty {
            addresses.append(("", address))
            return addresses
        }
        
        // Need to enrich the account
        do {
            print("🔄 [WalletListView] Enriching \(account.currency) account for multiple networks: \(account.accountId)")
            let enrichResponse = try await striga.enrichAccount(
                EnrichAccount(accountId: account.accountId, userId: userId)
            )
            
            // Check for multiple networks
            if let networks = enrichResponse.blockchainNetworks, !networks.isEmpty {
                for network in networks {
                    addresses.append((network.network, network.blockchainDepositAddress))
                    print("✅ [WalletListView] Got \(account.currency) address for \(network.network): \(network.blockchainDepositAddress)")
                }
            } else if let address = enrichResponse.blockchainDepositAddress {
                // Single address
                addresses.append(("", address))
                print("✅ [WalletListView] Got \(account.currency) address: \(address)")
            }
        } catch {
            print("❌ [WalletListView] Error enriching \(account.currency): \(error)")
        }
        
        return addresses
    }
    
    private func startMonitoringForAutoConversion() {
        // Start a timer to check balances and auto-convert
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task {
                await checkAndConvertBalances()
            }
        }
    }
    
    private func checkAndConvertBalances() async {
        guard !eurAccountId.isEmpty else { return }
        
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                return
            }
            
            // Get card's wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            // Get fresh wallet details
            let walletResponse = try await striga.getWallet(cardResponse.parentWalletId, userId: userId)
            
            // Check each crypto account for balances
            let accounts = [
                ("BTC", walletResponse.accounts.btc),
                ("USDC", walletResponse.accounts.usdc),
                ("ETH", walletResponse.accounts.eth),
                ("SOL", walletResponse.accounts.sol),
                ("BNB", walletResponse.accounts.bnb),
                ("POL", walletResponse.accounts.pol),
                ("USDT", walletResponse.accounts.usdt)
            ]
            
            for (currency, account) in accounts {
                guard let account = account else { continue }
                
                let balance = account.availableBalance.amount
                if balance != "0" && !balance.isEmpty {
                    print("💱 [WalletListView] Found \(balance) \(currency) - converting to EUR")
                    
                    // Execute swap to EUR
                    do {
                        let swapResponse = try await striga.swapCurrencies(.init(
                            userId: userId,
                            sourceAccountId: account.accountId,
                            destinationAccountId: eurAccountId,
                            amount: balance
                        ))
                        
                        print("✅ [WalletListView] Converted \(currency) to EUR successfully")
                        print("  - Transaction ID: \(swapResponse.id)")
                        print("  - Source: \(swapResponse.sourceAmount) \(currency)")
                        print("  - Destination: \(swapResponse.destinationAmount) EUR")
                    } catch {
                        print("❌ [WalletListView] Error converting \(currency): \(error)")
                    }
                }
            }
            
        } catch {
            print("❌ [WalletListView] Error checking balances: \(error)")
        }
    }
}

// MARK: - Wallet Row
private struct WalletRow: View {
    let wallet: WalletListView.WalletItem
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            // Icon - try to use existing icons, fallback to system icon
            if wallet.iconName == "vector-icon-card" || 
               wallet.iconName == "bitcoin-icon" {
                Image(wallet.iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
            } else {
                // Fallback icon for currencies without custom icons
                Image(systemName: iconForCurrency(wallet.currency))
                    .font(.system(size: 20))
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(wallet.currency)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .font(.custom("Inter", size: 16).weight(.medium))
                
                Text(wallet.displayAddress)
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .tracking(-0.25)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Copy icon on the right
            Button(action: onTap) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private func iconForCurrency(_ currency: String) -> String {
        switch currency {
        case "USDC", "USDT":
            return "dollarsign.circle"
        case "Ethereum", "ETH":
            return "e.circle"
        case "Solana", "SOL":
            return "s.circle"
        case "BNB":
            return "b.circle"
        case "Polygon", "POL":
            return "p.circle"
        default:
            return "wallet.pass"
        }
    }
}

// MARK: - Previews
#if DEBUG
#Preview {
    NavigationStack {
        WalletListView()
    }
}
#endif