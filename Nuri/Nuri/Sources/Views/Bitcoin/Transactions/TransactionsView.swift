import SwiftUI

struct TransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletState = WalletStateManager.shared
    @State private var isLoading = false
    @AppStorage("bitcoinNetwork") var bitcoinNetwork: String = "testnet3"

    // MARK: - Mock Data (Commented out - replaced with real transactions)
    /*
    private let mockTransactions: [Transaction] = [
        .init(iconName: "list-item-icon-paperplane_send", title: "Send Bitcoin",    sats: -5_300_000,    fiat: -1_000, date: "Nov 27"),
        .init(iconName: "vector-icon-card",             title: "Card Spend",      sats: nil,          fiat:  -10.53, date: "Nov 27"),
        .init(iconName: "money_topup",                   title: "Card Top-Up",     sats: nil,          fiat:   100,   date: "Nov 27"),
        .init(iconName: "list-item-icon-paperplane_send", title: "Send Bitcoin",    sats: -100_000,     fiat:  -100,   date: "Nov 27"),
        .init(iconName: "bitcoin_hand",                  title: "Bought Bitcoin",  sats: 133_700,      fiat:   133,   date: "Nov 27")
    ]
    */

    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                NuriHeader<AnyView, AnyView>.logo(title: "Transactions", onClose: { dismiss() })

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if walletState.transactions.isEmpty && isLoading {
                            // Loading state - only show when no cached data
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Loading transactions...")
                                    .font(.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                            }
                            .padding(.top, 40)
                        } else if walletState.transactions.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "bitcoin.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                                Text("No transactions yet")
                                    .font(.custom("Inter", size: 18).weight(.medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                                Text("Your Bitcoin transactions will appear here")
                                    .font(.custom("Inter", size: 14).weight(.medium))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        } else {
                            // Real transactions
                            ForEach(Array(walletState.transactions.enumerated()), id: \.offset) { index, cachedTx in
                                RealTransactionRow(cachedTx: cachedTx, network: bitcoinNetwork)

                                if index != walletState.transactions.count - 1 {
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
            await loadTransactions()
        }
        .refreshable {
            await refreshTransactions()
        }
    }
    
    // MARK: - Data Loading Methods
    
    private func loadTransactions() async {
        print("📋 [TransactionsView] Loading transactions...")
        
        let walletService = BitcoinWalletService.shared
        
        // Ensure wallet is initialized first
        if !walletService.hasWallet() {
            print("⚠️ [TransactionsView] Wallet not initialized, initializing now...")
            walletService.initializeWalletOnAppStart()
            
            // Wait for initialization
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Only show loading state if we have no cached transactions
        if walletState.transactions.isEmpty {
            isLoading = true
        }
        
        // Get cached transactions (fast) and refresh in background if needed
        let _ = await walletState.getTransactions(forceRefresh: false)
        
        isLoading = false
    }
    
    private func refreshTransactions() async {
        print("📋 [TransactionsView] Refreshing transactions...")
        // Force refresh transactions from network
        let _ = await walletState.getTransactions(forceRefresh: true)
    }
}

// MARK: - Row
private struct TransactionRow: View {
    let tx: Transaction

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(tx.iconName)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 0) {
                Text(tx.title)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .font(.custom("Inter", size: 16).weight(.medium))
                Text(tx.date)
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .tracking(-0.25)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                if let sats = tx.sats {
                    satsText(sats: sats)
                }

                if let fiat = tx.fiat {
                    fiatText(fiat: fiat, hasSats: tx.sats != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
    }

    // MARK: - Helpers
    private func satsText(sats: Int64) -> Text {
        let isPositive = sats > 0
        let color: Color = isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack")

        return Text("\(isPositive ? "" : "-")₿ \(abs(sats))")
            .foregroundColor(color)
            .font(.custom("Inter", size: 16).weight(.medium))
    }

    private func fiatText(fiat: Double, hasSats: Bool) -> Text {
        let isPositive = fiat > 0

        if hasSats {
            // Secondary fiat line under sats amount
            return Text(String(format: "%@%.0f €", isPositive ? "" : "-", abs(fiat)))
                .foregroundColor(Color(hex: "#6D6D86"))
                .font(.custom("Inter", size: 14).weight(.medium))
                .tracking(-0.25)
        } else {
            // Single-line amount for card rows
            let color: Color = isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack")
            return Text(String(format: "%@%.2f EUR", isPositive ? "" : "-", abs(fiat)))
                .foregroundColor(color)
                .font(.custom("Inter", size: 16).weight(.medium))
        }
    }
}

// MARK: - Real Transaction Row
private struct RealTransactionRow: View {
    let cachedTx: WalletStateManager.CachedTransaction
    let network: String

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(cachedTx.iconName)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(cachedTx.type.rawValue)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                        .font(.custom("Inter", size: 16).weight(.medium))
                    
                    // Show pending status if not confirmed
                    if let statusText = cachedTx.statusText {
                        Text("(\(statusText))")
                            .foregroundColor(Color(hex: "#6D6D86"))
                            .font(.custom("Inter", size: 14).weight(.medium))
                    }
                }
                
                Text(cachedTx.displayDate)
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.custom("Inter", size: 14).weight(.medium))
                    .tracking(-0.25)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                // Bitcoin amount with sign
                satsText(sats: cachedTx.amountWithSign)
                
                // EUR amount with sign  
                fiatText(fiat: cachedTx.eurAmountWithSign)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
        .onTapGesture {
            handleTransactionTap()
        }
    }
    
    // MARK: - Transaction Tap Handler
    private func handleTransactionTap() {
        print("📋 [RealTransactionRow] Transaction tapped: \(cachedTx.txId)")
        
        // Copy transaction ID to clipboard
        UIPasteboard.general.string = cachedTx.txId
        print("📋 [RealTransactionRow] Transaction ID copied to clipboard: \(cachedTx.txId)")
        
        // Open block explorer in browser (use appropriate network)
        let explorerURL = NetworkConfiguration.shared.blockExplorerURL(for: cachedTx.txId)
        
        if let url = URL(string: explorerURL) {
            UIApplication.shared.open(url)
            print("📋 [RealTransactionRow] Opening explorer: \(explorerURL)")
        } else {
            print("❌ [RealTransactionRow] Failed to create URL: \(explorerURL)")
        }
    }

    // MARK: - Helpers
    private func satsText(sats: Int64) -> Text {
        let isPositive = sats > 0
        let color: Color = isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack")

        return Text("\(isPositive ? "" : "-")₿ \(abs(sats))")
            .foregroundColor(color)
            .font(.custom("Inter", size: 16).weight(.medium))
    }

    private func fiatText(fiat: Double) -> Text {
        let isPositive = fiat > 0

        // Secondary fiat line under sats amount (same styling as original)
        return Text(String(format: "%@%.0f €", isPositive ? "" : "-", abs(fiat)))
            .foregroundColor(Color(hex: "#6D6D86"))
            .font(.custom("Inter", size: 14).weight(.medium))
            .tracking(-0.25)
    }
}

// MARK: - Model
private struct Transaction: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let sats: Int64?
    let fiat: Double?
    let date: String
}

// MARK: - Previews
#if DEBUG
#Preview {
    TransactionsView()
}
#endif 
