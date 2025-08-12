import SwiftUI
import StrigaAPI

struct UnifiedTransactionsViewSimple: View {
    @Environment(\.dismiss) private var dismiss
    @State private var allTransactions: [UnifiedTransaction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let striga = StrigaService.shared
    @StateObject private var walletState = WalletStateManager.shared
    
    // Simplified transaction model
    struct UnifiedTransaction: Identifiable {
        let id: String
        let iconName: String
        let title: String
        let amount: String  // Already formatted with sign
        let currency: String  // EUR, BTC, etc
        let date: Date
        let displayDate: String
        let txId: String  // For blockchain explorer
        let isBlockchain: Bool
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - exactly as original
                NuriHeader<AnyView, AnyView>.logo(title: "All Transactions", onClose: { dismiss() })
                
                if isLoading && allTransactions.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView("Loading transactions...")
                        Spacer()
                    }
                } else if allTransactions.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#6D6D86"))
                        Text("No transactions yet")
                            .font(.custom("Inter", size: 18).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(allTransactions.enumerated()), id: \.offset) { index, tx in
                                TransactionRowSimple(transaction: tx)
                                
                                if index != allTransactions.count - 1 {
                                    Color.clear.frame(height: 8)
                                    Color(hex: "#E0E0E0").frame(height: 1)
                                    Color.clear.frame(height: 8)
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .task {
            await loadAllTransactions()
        }
    }
    
    private func loadAllTransactions() async {
        // Show existing Bitcoin transactions immediately
        let btcTransactions = await walletState.getTransactions(forceRefresh: false)
        var allTx: [UnifiedTransaction] = []
        
        // Add Bitcoin wallet transactions
        for btcTx in btcTransactions {
            let isSent = btcTx.type == .send
            let tx = UnifiedTransaction(
                id: btcTx.txId,
                iconName: isSent ? "list-item-icon-paperplane_send" : "bitcoin_hand",
                title: isSent ? "Send Bitcoin" : "Received Bitcoin",
                amount: "\(isSent ? "-" : "")₿ \(btcTx.amountSats)",
                currency: "BTC",
                date: btcTx.date,
                displayDate: btcTx.displayDate,
                txId: btcTx.txId,
                isBlockchain: true
            )
            allTx.append(tx)
        }
        
        // Sort and display immediately
        allTx.sort { $0.date > $1.date }
        await MainActor.run {
            self.allTransactions = allTx
            self.isLoading = false
        }
        
        // Now load Striga transactions in background
        await loadStrigaTransactions()
    }
    
    private func loadStrigaTransactions() async {
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId else {
                print("ℹ️ [UnifiedTransactions] No Striga user ID - showing Bitcoin transactions only")
                return
            }
            
            guard let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                print("ℹ️ [UnifiedTransactions] No Striga card ID - showing Bitcoin transactions only")
                return
            }
            
            print("🔄 Loading Striga transactions for user: \(userId), card: \(cardId)")
            
            var strigaTx: [UnifiedTransaction] = []
            
            // Get card's wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            let walletId = cardResponse.parentWalletId
            let walletResponse = try await striga.getWallet(walletId, userId: userId)
            
            // Date range - last 30 days
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            let fromTimestamp = Int64(startDate.timeIntervalSince1970 * 1000)
            let toTimestamp = Int64(endDate.timeIntervalSince1970 * 1000)
            
            // Only get EUR transactions - keep it simple
            let accounts: [(String, CreateWalletResponse.Account?)] = [
                ("EUR", walletResponse.accounts.eur)
            ]
            
            for (currency, account) in accounts {
                guard let account = account else { continue }
                
                print("🔍 [UnifiedTransactions] Fetching \(currency) transactions for account \(account.accountId)")
                
                do {
                    let statement = try await striga.accountStatements(.init(
                        userId: userId,
                        walletId: walletId,
                        accountId: account.accountId,
                        startDate: fromTimestamp,
                        endDate: toTimestamp,
                        page: 1
                    ))
                    
                    print("✅ [UnifiedTransactions] Found \(statement.transactions.count) \(currency) transactions")
                    
                    for (index, tx) in statement.transactions.enumerated() {
                        print("   Transaction \(index + 1): \(tx.txType) - \(tx.amount) \(tx.currency)")
                        let unifiedTx = convertStrigaTransaction(tx, currency: currency)
                        strigaTx.append(unifiedTx)
                    }
                } catch {
                    print("⚠️ [UnifiedTransactions] Could not fetch \(currency) transactions:")
                    print("   Account: \(account.accountId)")
                    print("   Error: \(error.localizedDescription)")
                    // Continue silently - don't break the whole view
                }
            }
            
            // Merge with existing transactions
            var allTx = self.allTransactions
            allTx.append(contentsOf: strigaTx)
            allTx.sort { $0.date > $1.date }
            
            await MainActor.run {
                self.allTransactions = allTx
            }
            
        } catch {
            print("⚠️ [UnifiedTransactions] Could not load Striga transactions: \(error.localizedDescription)")
            // Not a critical error - user can still see Bitcoin transactions
        }
    }
    
    private func convertStrigaTransaction(_ tx: StrigaAccountTransaction, currency: String) -> UnifiedTransaction {
        // Parse date
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: tx.timestamp) ?? Date()
        
        // Format display date like Bitcoin transactions (e.g. "Nov 27")
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd"
        let displayDate = displayFormatter.string(from: date)
        
        // Parse amount (tx.amount already handles debit/credit with sign)
        let amountDouble = Double(tx.amount) ?? 0
        let isPositive = amountDouble > 0
        
        // Determine icon and title based on transaction type
        let txType = tx.txType.lowercased()
        let memo = (tx.memo ?? "").lowercased()
        
        var iconName = "vector-icon-card"  // default
        var title = tx.txType
        
        if txType.contains("card_authorization") {
            iconName = "vector-icon-card"
            title = "Card Spend"
        } else if txType.contains("sepa_payin") {
            iconName = "money_topup"
            title = "SEPA Top-Up"
        } else if txType.contains("exchange_credit") {
            iconName = "transfer_vertical"
            title = "Exchange"
        } else if txType.contains("exchange_debit") {
            iconName = "transfer_vertical"
            title = "Exchange"
        } else if currency != "EUR" {
            iconName = isPositive ? "bitcoin_hand" : "list-item-icon-paperplane_send"
            title = isPositive ? "Received \(currency)" : "Send \(currency)"
        } else {
            iconName = isPositive ? "money_topup" : "vector-icon-card"
            title = isPositive ? "Top-Up" : "Card Spend"
        }
        
        // Format amount with currency
        let amountString: String
        if currency == "EUR" {
            // Convert cents to euros (divide by 100)
            let euroAmount = abs(amountDouble) / 100.0
            amountString = String(format: "%@€%.2f", isPositive ? "+" : "-", euroAmount)
        } else if currency == "BTC" {
            // Striga BTC is in BTC, convert to sats
            let sats = Int64(abs(amountDouble * 100_000_000))
            amountString = "\(isPositive ? "" : "-")₿ \(sats)"
        } else {
            amountString = String(format: "%@%.4f %@", isPositive ? "+" : "-", abs(amountDouble), currency)
        }
        
        return UnifiedTransaction(
            id: tx.id,
            iconName: iconName,
            title: title,
            amount: amountString,
            currency: currency,
            date: date,
            displayDate: displayDate,
            txId: tx.txHash ?? tx.id,
            isBlockchain: tx.txHash != nil
        )
    }
}

// Simple transaction row - matches original Bitcoin design exactly
private struct TransactionRowSimple: View {
    let transaction: UnifiedTransactionsViewSimple.UnifiedTransaction
    
    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(transaction.iconName)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(transaction.title)
                    .foregroundColor(Color("PrimaryNuriBlack"))
                    .font(.custom("Inter", size: 16).weight(.medium))
                
                Text(transaction.displayDate)
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.custom("Inter", size: 15).weight(.regular))
                    .tracking(-0.25)
            }
            
            Spacer()
            
            // Amount with proper color - exactly like Bitcoin transactions
            if transaction.currency == "BTC" {
                // Bitcoin amount
                Text(transaction.amount)
                    .foregroundColor(transaction.amount.starts(with: "-") ? Color("PrimaryNuriBlack") : Color(hex: "#02542d"))
                    .font(.custom("Inter", size: 16).weight(.medium))
            } else if transaction.currency == "EUR" {
                // EUR amount
                Text(transaction.amount)
                    .foregroundColor(transaction.amount.starts(with: "-") ? Color("PrimaryNuriBlack") : Color(hex: "#02542d"))
                    .font(.custom("Inter", size: 16).weight(.medium))
            } else {
                // Other currencies
                Text(transaction.amount)
                    .foregroundColor(transaction.amount.starts(with: "-") ? Color("PrimaryNuriBlack") : Color(hex: "#02542d"))
                    .font(.custom("Inter", size: 16).weight(.medium))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
        .onTapGesture {
            handleTap()
        }
    }
    
    private func handleTap() {
        // Copy ID to clipboard
        UIPasteboard.general.string = transaction.txId
        
        // Open explorer for blockchain transactions
        if transaction.isBlockchain {
            var explorerURL: String?
            
            if transaction.currency == "BTC" {
                explorerURL = "https://mempool.space/tx/\(transaction.txId)"
            } else if transaction.currency == "ETH" {
                explorerURL = "https://etherscan.io/tx/\(transaction.txId)"
            } else if transaction.currency == "SOL" {
                explorerURL = "https://solscan.io/tx/\(transaction.txId)"
            }
            
            if let urlString = explorerURL, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}