import SwiftUI
import StrigaAPI
typealias StrigaTransaction = StrigaAPI.Transaction

struct UnifiedTransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var allTransactions: [UnifiedTransaction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let striga = StrigaService.shared
    @StateObject private var walletState = WalletStateManager.shared
    
    // Unified transaction model that combines all types
    struct UnifiedTransaction: Identifiable {
        let id: String
        let type: TransactionType
        let amount: String
        let currency: String
        let date: Date
        let displayDate: String
        let description: String
        let status: String
        let fromAccount: String?
        let toAccount: String?
        let isPositive: Bool
        
        enum TransactionType {
            case bitcoin(sent: Bool)
            case cardAuthorization
            case cardSpend
            case cardTopUp
            case swap(from: String, to: String)
            case sepaPayIn
            case sepaPayOut
            case ibanTransfer(sent: Bool)
            case exchange
            case crypto(currency: String, sent: Bool)
            
            var iconName: String {
                switch self {
                case .bitcoin(let sent):
                    return sent ? "list-item-icon-paperplane_send" : "bitcoin_hand"
                case .cardAuthorization, .cardSpend:
                    return "vector-icon-card"
                case .cardTopUp:
                    return "money_topup"
                case .swap:
                    return "transfer_vertical"
                case .sepaPayIn:
                    return "money_topup"
                case .sepaPayOut:
                    return "list-item-icon-paperplane_send"
                case .ibanTransfer(let sent):
                    return sent ? "list-item-icon-paperplane_send" : "money_topup"
                case .exchange:
                    return "transfer_vertical"
                case .crypto(_, let sent):
                    return sent ? "list-item-icon-paperplane_send" : "bitcoin_hand"
                }
            }
            
            var title: String {
                switch self {
                case .bitcoin(let sent):
                    return sent ? "Send Bitcoin" : "Received Bitcoin"
                case .cardAuthorization:
                    return "Card Authorization"
                case .cardSpend:
                    return "Card Payment"
                case .cardTopUp:
                    return "Card Top-Up"
                case .swap(let from, let to):
                    return from == to ? "Exchange Credit" : "Swap \(from) to \(to)"
                case .sepaPayIn:
                    return "SEPA Payin Completed"
                case .sepaPayOut:
                    return "SEPA PayOut"
                case .ibanTransfer(let sent):
                    return sent ? "IBAN Transfer" : "IBAN Received"
                case .exchange:
                    return "Exchange Credit"
                case .crypto(let currency, let sent):
                    return sent ? "Send \(currency)" : "Received \(currency)"
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                NuriHeader<AnyView, AnyView>.logo(title: "All Transactions", onClose: { dismiss() })
                
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading all transactions...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                } else if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task {
                                await loadAllTransactions()
                            }
                        }
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
                                UnifiedTransactionRow(transaction: tx)
                                
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
        .refreshable {
            await loadAllTransactions()
        }
    }
    
    private func loadAllTransactions() async {
        await MainActor.run {
            // Only show loading if we have no cached data
            if allTransactions.isEmpty {
                isLoading = true
            }
            errorMessage = nil
        }
        
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                throw NSError(domain: "TransactionsView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user or card ID"])
            }
            
            print("🔄 [UnifiedTransactionsView] Loading all transactions for user: \(userId)")
            
            var allTx: [UnifiedTransaction] = []
            
            // First, quickly load Bitcoin wallet transactions (these are cached)
            let btcTransactions = await walletState.getTransactions(forceRefresh: false)
            print("🪙 [UnifiedTransactionsView] Found \(btcTransactions.count) Bitcoin wallet transactions")
            for btcTx in btcTransactions {
                let isSent = btcTx.type == .send
                let unifiedTx = UnifiedTransaction(
                    id: btcTx.txId,
                    type: .bitcoin(sent: isSent),
                    amount: String(btcTx.amountSats),
                    currency: "BTC",
                    date: btcTx.date,
                    displayDate: btcTx.displayDate,
                    description: btcTx.type.rawValue,
                    status: btcTx.isConfirmed ? "Confirmed" : "Pending",
                    fromAccount: isSent ? "Bitcoin Wallet" : nil,
                    toAccount: !isSent ? "Bitcoin Wallet" : nil,
                    isPositive: !isSent
                )
                allTx.append(unifiedTx)
                print("   - BTC tx: \(btcTx.txId.prefix(10))... - \(btcTx.type.rawValue) - \(btcTx.amountSats) sats")
                print("     Date: \(btcTx.date) - Display: \(btcTx.displayDate)")
            }
            
            // Sort and display Bitcoin transactions immediately
            allTx.sort { $0.date > $1.date }
            await MainActor.run {
                self.allTransactions = allTx
                self.isLoading = false
            }
            
            // Now fetch Striga transactions in the background
            // Get card's wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            let walletId = cardResponse.parentWalletId
            print("💳 [UnifiedTransactionsView] Found wallet ID: \(walletId)")
            
            // Get wallet details to find all accounts
            let walletResponse = try await striga.getWallet(walletId, userId: userId)
            
            // Calculate date range (last 30 days for faster loading)
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            
            // Convert dates to Unix timestamps in milliseconds (Striga API requirement)
            let fromTimestamp = Int64(startDate.timeIntervalSince1970 * 1000)
            let toTimestamp = Int64(endDate.timeIntervalSince1970 * 1000)
            
            print("📅 [UnifiedTransactionsView] Date range: \(fromTimestamp) to \(toTimestamp) (Unix timestamps in ms)")
            
            // Fetch transactions for each account
            let accounts: [(String, CreateWalletResponse.Account?)] = [
                ("EUR", walletResponse.accounts.eur),
                ("BTC", walletResponse.accounts.btc),
                ("ETH", walletResponse.accounts.eth),
                ("USDC", walletResponse.accounts.usdc),
                ("USDT", walletResponse.accounts.usdt),
                ("BNB", walletResponse.accounts.bnb),
                ("POL", walletResponse.accounts.pol),
                ("SOL", walletResponse.accounts.sol)
            ]
            
            for (currency, account) in accounts {
                guard let account = account else { continue }
                
                print("📊 [UnifiedTransactionsView] Fetching \(currency) transactions for account: \(account.accountId)")
                
                do {
                    print("🔍 [UnifiedTransactionsView] Calling accountStatements with:")
                    print("   - userId: \(userId)")
                    print("   - walletId: \(walletId)")
                    print("   - accountId: \(account.accountId)")
                    print("   - startDate: \(fromTimestamp)")
                    print("   - endDate: \(toTimestamp)")
                    print("   - page: 1")
                    
                    let statement = try await striga.accountStatements(.init(
                        userId: userId,
                        walletId: walletId,
                        accountId: account.accountId,
                        startDate: fromTimestamp,
                        endDate: toTimestamp,
                        page: 1
                    ))
                    
                    print("✅ [UnifiedTransactionsView] Found \(statement.transactions.count) \(currency) transactions")
                    
                    // Convert Striga transactions to unified format
                    for strigaTx in statement.transactions {
                        print("   📝 Transaction details:")
                        print("      - ID: \(strigaTx.id)")
                        print("      - Type: \(strigaTx.transactionType)")
                        print("      - Amount: \(strigaTx.amount) \(strigaTx.currency)")
                        print("      - Status: \(strigaTx.status)")
                        print("      - Timestamp: \(strigaTx.timestamp)")
                        print("      - Memo: \(strigaTx.memo ?? "N/A")")
                        
                        let unifiedTx = convertToUnifiedTransaction(
                            strigaTx: strigaTx,
                            currency: currency,
                            accountId: account.accountId
                        )
                        
                        // Log the parsed date for debugging
                        print("      - Parsed Date: \(unifiedTx.date)")
                        print("      - Display Date: \(unifiedTx.displayDate)")
                        
                        allTx.append(unifiedTx)
                    }
                } catch {
                    print("❌ [UnifiedTransactionsView] Error fetching \(currency) transactions:")
                    print("   Error: \(error)")
                    if let urlError = error as? URLError {
                        print("   URL Error: \(urlError.localizedDescription)")
                    } else if let decodingError = error as? DecodingError {
                        print("   Decoding Error: \(decodingError)")
                    }
                    // Continue with other accounts even if one fails
                }
            }
            
            // Sort all transactions by date (newest first)
            print("🕒 [UnifiedTransactionsView] Sorting \(allTx.count) transactions by date...")
            
            // Log dates before sorting
            for (index, tx) in allTx.enumerated() {
                let typeStr: String
                switch tx.type {
                case .bitcoin(let sent):
                    typeStr = sent ? "Send BTC" : "Receive BTC"
                case .swap(let from, let to):
                    typeStr = "Swap \(from)->\(to)"
                case .exchange:
                    typeStr = "Exchange Credit"
                default:
                    typeStr = tx.type.title
                }
                print("  \(index): \(tx.date) - \(typeStr) - \(tx.amount) \(tx.currency) - \(tx.description.prefix(30))")
            }
            
            allTx.sort { $0.date > $1.date }
            
            print("📊 [UnifiedTransactionsView] After sorting:")
            for (index, tx) in allTx.prefix(5).enumerated() {
                let typeStr: String
                switch tx.type {
                case .bitcoin(let sent):
                    typeStr = sent ? "Send BTC" : "Receive BTC"
                case .swap(let from, let to):
                    typeStr = "Swap \(from)->\(to)"
                case .exchange:
                    typeStr = "Exchange Credit"
                default:
                    typeStr = tx.type.title
                }
                print("  \(index): \(tx.date) - \(typeStr) - \(tx.amount) \(tx.currency)")
            }
            
            print("📊 [UnifiedTransactionsView] Total transactions loaded: \(allTx.count)")
            
            await MainActor.run {
                self.allTransactions = allTx
                self.isLoading = false
            }
            
        } catch {
            print("❌ [UnifiedTransactionsView] Error loading transactions: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func convertToUnifiedTransaction(strigaTx: StrigaTransaction, currency: String, accountId: String) -> UnifiedTransaction {
        // Parse the transaction type
        let type: UnifiedTransaction.TransactionType
        let description = strigaTx.memo ?? strigaTx.transactionType
        let amountDouble = Double(strigaTx.amount) ?? 0
        let isPositive = amountDouble > 0
        
        print("      🔍 Parsing transaction type: '\(strigaTx.transactionType)'")
        print("      📋 Memo/Description: '\(description)'")
        
        // Determine transaction type based on Striga transaction type and description
        let txTypeLower = strigaTx.transactionType.lowercased()
        let descLower = description.lowercased()
        
        if txTypeLower.contains("card_authorization") || descLower.contains("card authorization") {
            type = .cardAuthorization
            print("      ✅ Identified as: Card Authorization")
        } else if txTypeLower.contains("swap") || descLower.contains("swap") {
            // Parse swap details from description
            var fromCurrency = currency
            var toCurrency = "EUR"
            
            // Try to extract from pattern like "Swap 0.00111340 BTC to EUR"
            if let swapRange = descLower.range(of: "swap") {
                let afterSwap = String(description[swapRange.upperBound...])
                let components = afterSwap.components(separatedBy: " ").filter { !$0.isEmpty }
                
                // Find currency codes
                for (index, component) in components.enumerated() {
                    let upperComponent = component.uppercased()
                    if ["BTC", "ETH", "EUR", "USDC", "USDT", "BNB", "POL", "SOL"].contains(upperComponent) {
                        if fromCurrency == currency {
                            fromCurrency = upperComponent
                        } else if component.lowercased() == "to" && index + 1 < components.count {
                            let nextUpper = components[index + 1].uppercased()
                            if ["BTC", "ETH", "EUR", "USDC", "USDT", "BNB", "POL", "SOL"].contains(nextUpper) {
                                toCurrency = nextUpper
                            }
                        }
                    }
                }
            }
            
            type = .swap(from: fromCurrency, to: toCurrency)
            print("      ✅ Identified as: Swap \(fromCurrency) to \(toCurrency)")
        } else if txTypeLower.contains("exchange_credit") || descLower.contains("exchange credit") {
            // Check if it's a failed swap refund
            if descLower.contains("failed swap") {
                // Extract currencies from "Failed Swap X.XX ETH to EUR" pattern
                var fromCurrency = currency
                var toCurrency = "EUR"
                if let fromRange = descLower.range(of: "eth") {
                    fromCurrency = "ETH"
                } else if let fromRange = descLower.range(of: "btc") {
                    fromCurrency = "BTC"
                }
                type = .swap(from: fromCurrency, to: toCurrency)
                print("      🔴 Identified as: Failed Swap Refund \(fromCurrency) to \(toCurrency)")
            } else {
                type = .exchange
                print("      ✅ Identified as: Exchange Credit")
            }
        } else if txTypeLower.contains("sepa_payin_completed") || descLower.contains("sepa_payin_completed") || descLower.contains("sepa payin") {
            type = .sepaPayIn
            print("      ✅ Identified as: SEPA PayIn")
        } else if txTypeLower.contains("sepa_payout") || descLower.contains("sepa payout") {
            type = .sepaPayOut
            print("      ✅ Identified as: SEPA PayOut")
        } else if txTypeLower.contains("card") || descLower.contains("card") {
            if isPositive {
                type = .cardTopUp
                print("      ✅ Identified as: Card Top-Up")
            } else {
                type = .cardSpend
                print("      ✅ Identified as: Card Spend")
            }
        } else if txTypeLower.contains("transfer") || txTypeLower.contains("sepa") {
            type = .ibanTransfer(sent: !isPositive)
            print("      ✅ Identified as: IBAN Transfer (sent: \(!isPositive))")
        } else if txTypeLower.contains("exchange") {
            type = .exchange
            print("      ✅ Identified as: Exchange")
        } else if currency != "EUR" {
            // For crypto currencies
            type = .crypto(currency: currency, sent: !isPositive)
            print("      ✅ Identified as: Crypto \(currency) (sent: \(!isPositive))")
        } else {
            // Default based on amount for EUR
            if isPositive {
                type = .cardTopUp
                print("      ✅ Identified as: Card Top-Up (default)")
            } else {
                type = .cardSpend
                print("      ✅ Identified as: Card Spend (default)")
            }
        }
        
        // Parse date - Striga uses ISO8601 format with milliseconds
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = dateFormatter.date(from: strigaTx.timestamp) ?? Date()
        
        print("      🕒 Date parsing: \(strigaTx.timestamp) -> \(date)")
        
        // Format display date and time like "10 Aug 04:50 PM"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd MMM hh:mm a"
        let displayDate = displayFormatter.string(from: date)
        
        // Format amount - Striga returns amounts in smallest units (cents for EUR, wei for ETH, etc.)
        let amountString: String
        if currency == "EUR" {
            // EUR is in cents, divide by 100
            let euros = abs(amountDouble) / 100.0
            amountString = String(format: "%.2f", euros)
        } else if currency == "BTC" {
            // BTC from Striga is in satoshis
            amountString = String(Int64(abs(amountDouble)))
        } else if currency == "ETH" || currency == "BNB" || currency == "POL" {
            // ETH/BNB/POL are in wei (10^18), convert to readable format
            let ethAmount = abs(amountDouble) / 1_000_000_000_000_000_000
            amountString = String(format: "%.6f", ethAmount)
        } else if currency == "USDC" || currency == "USDT" {
            // USDC/USDT are in cents (smallest unit with 2 decimals)
            let dollars = abs(amountDouble) / 100.0
            amountString = String(format: "%.2f", dollars)
        } else if currency == "SOL" {
            // SOL is in lamports (10^9)
            let solAmount = abs(amountDouble) / 1_000_000_000
            amountString = String(format: "%.6f", solAmount)
        } else {
            // Default formatting
            amountString = String(format: "%.6f", abs(amountDouble))
        }
        
        return UnifiedTransaction(
            id: strigaTx.id,
            type: type,
            amount: amountString,
            currency: currency,
            date: date,
            displayDate: displayDate,
            description: description,
            status: strigaTx.status.capitalized,
            fromAccount: !isPositive ? accountId : nil,
            toAccount: isPositive ? accountId : nil,
            isPositive: isPositive
        )
    }
}

// MARK: - Transaction Row
private struct UnifiedTransactionRow: View {
    let transaction: UnifiedTransactionsView.UnifiedTransaction
    @State private var isExpanded = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(transaction.type.iconName)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    // Title line - simplified for all transaction types
                    Text(transaction.type.title)
                        .foregroundColor(Color("PrimaryNuriBlack"))
                        .font(.custom("Inter", size: 16).weight(.medium))
                    
                    // Status badge only (no transaction ID)
                    HStack(spacing: 4) {
                        // Show status badge for all statuses
                        if transaction.status.lowercased() == "success" {
                            Text("Success")
                                .foregroundColor(Color(hex: "#02542d"))
                                .font(.custom("Inter", size: 12).weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#02542d").opacity(0.1))
                                .cornerRadius(4)
                        } else if transaction.status.lowercased() == "failed" || 
                                  transaction.description.lowercased().contains("failed") {
                            Text("Failed")
                                .foregroundColor(Color(hex: "#DC2626"))
                                .font(.custom("Inter", size: 12).weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#DC2626").opacity(0.1))
                                .cornerRadius(4)
                        } else if transaction.status.lowercased() == "pending" {
                            Text("Pending")
                                .foregroundColor(Color(hex: "#F59E0B"))
                                .font(.custom("Inter", size: 12).weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#F59E0B").opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Text(transaction.displayDate)
                    .foregroundColor(Color(hex: "#6D6D86"))
                    .font(.custom("Inter", size: 12).weight(.regular))
                    .tracking(-0.25)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 0) {
                // Amount with appropriate symbol
                if transaction.currency == "BTC" {
                    // Bitcoin: show in sats with ₿ symbol
                    Text("\(transaction.isPositive ? "" : "-")₿ \(transaction.amount)")
                        .foregroundColor(transaction.isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack"))
                        .font(.custom("Inter", size: 16).weight(.medium))
                } else if transaction.currency == "EUR" {
                    // EUR: show with + or - and € symbol with space
                    Text(String(format: "%@€ %.2f", transaction.isPositive ? "+" : "-", Double(transaction.amount) ?? 0))
                        .foregroundColor(transaction.isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack"))
                        .font(.custom("Inter", size: 16).weight(.medium))
                } else if transaction.currency == "ETH" {
                    // ETH: show with proper symbol
                    Text(String(format: "%@Ξ %@", transaction.isPositive ? "+" : "-", transaction.amount))
                        .foregroundColor(transaction.isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack"))
                        .font(.custom("Inter", size: 16).weight(.medium))
                } else if transaction.currency == "USDC" || transaction.currency == "USDT" {
                    // Stablecoins: show with $ symbol
                    Text(String(format: "%@$%.2f", transaction.isPositive ? "+" : "-", Double(transaction.amount) ?? 0))
                        .foregroundColor(transaction.isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack"))
                        .font(.custom("Inter", size: 16).weight(.medium))
                } else {
                    // Other currencies
                    HStack(spacing: 2) {
                        Text(transaction.isPositive ? "+" : "-")
                        Text(transaction.currency)
                        Text(transaction.amount)
                    }
                    .foregroundColor(transaction.isPositive ? Color(hex: "#02542d") : Color("PrimaryNuriBlack"))
                    .font(.custom("Inter", size: 16).weight(.medium))
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(minHeight: 40)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                // For Bitcoin transactions, open explorer
                // For Striga transactions, expand to show details
                switch transaction.type {
                case .bitcoin:
                    handleBitcoinTransactionTap()
                default:
                    isExpanded.toggle()
                }
            }
        }
        
        // Expandable details for Striga transactions
        if isExpanded {
            switch transaction.type {
            case .bitcoin:
                EmptyView() // Bitcoin transactions don't expand
            default:
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Transaction ID
                    HStack {
                        Text("Transaction ID:")
                            .font(.custom("Inter", size: 12).weight(.medium))
                            .foregroundColor(Color(hex: "#6D6D86"))
                        Text(transaction.id)
                            .font(.custom("Inter", size: 12))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    // Description if available
                    if !transaction.description.isEmpty && transaction.description != transaction.type.title {
                        HStack {
                            Text("Details:")
                                .font(.custom("Inter", size: 12).weight(.medium))
                                .foregroundColor(Color(hex: "#6D6D86"))
                            Text(transaction.description)
                                .font(.custom("Inter", size: 12))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                        }
                    }
                    
                    // Status
                    HStack {
                        Text("Status:")
                            .font(.custom("Inter", size: 12).weight(.medium))
                            .foregroundColor(Color(hex: "#6D6D86"))
                        Text(transaction.status)
                            .font(.custom("Inter", size: 12))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                    }
                    
                    // Copy button
                    Button(action: {
                        UIPasteboard.general.string = transaction.id
                        print("📋 Transaction ID copied: \(transaction.id)")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                            Text("Copy ID")
                                .font(.custom("Inter", size: 11).weight(.medium))
                        }
                        .foregroundColor(Color(hex: "#6D6D86"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(hex: "#E0E0E0"), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func handleBitcoinTransactionTap() {
        print("📋 [UnifiedTransactionRow] Bitcoin transaction tapped: \(transaction.id)")
        
        // Copy transaction ID to clipboard
        UIPasteboard.general.string = transaction.id
        print("📋 [UnifiedTransactionRow] Transaction ID copied to clipboard")
        
        // Open mempool.space for Bitcoin transactions
        let explorerURL = "https://mempool.space/tx/\(transaction.id)"
        if let url = URL(string: explorerURL) {
            UIApplication.shared.open(url)
            print("📋 [UnifiedTransactionRow] Opening explorer: \(explorerURL)")
        }
    }
}

#if DEBUG
#Preview {
    UnifiedTransactionsView()
}
#endif