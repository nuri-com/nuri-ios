import SwiftUI
import StrigaAPI

struct StrigaTransactionsDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var strigaTransactions: [StrigaTransaction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    private let striga = StrigaService.shared
    
    struct StrigaTransaction: Identifiable {
        let id: String
        let type: String
        let amount: String
        let currency: String
        let date: String
        let timestamp: Date
        let accountType: String
        let raw: String
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#F0F0F0").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                NuriHeader<AnyView, AnyView>.logo(title: "Striga Transactions Debug", onClose: { dismiss() })
                
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading Striga transactions...")
                        Spacer()
                    }
                } else if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task {
                                await loadStrigaTransactions()
                            }
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            Text("Found \(strigaTransactions.count) Striga transactions")
                                .font(.custom("Inter", size: 14).weight(.medium))
                                .padding()
                            
                            ForEach(Array(strigaTransactions.enumerated()), id: \.offset) { index, tx in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(tx.type)
                                            .font(.custom("Inter", size: 14).weight(.bold))
                                        Spacer()
                                        Text("\(tx.amount) \(tx.currency)")
                                            .font(.custom("Inter", size: 14).weight(.medium))
                                    }
                                    
                                    Text("Account: \(tx.accountType)")
                                        .font(.custom("Inter", size: 12))
                                        .foregroundColor(.gray)
                                    
                                    Text("Date: \(tx.date)")
                                        .font(.custom("Inter", size: 12))
                                        .foregroundColor(.gray)
                                    
                                    Text("ID: \(tx.id)")
                                        .font(.custom("Inter", size: 10))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                    
                                    Text("Raw: \(tx.raw)")
                                        .font(.custom("Inter", size: 10))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadStrigaTransactions()
        }
    }
    
    private func loadStrigaTransactions() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            strigaTransactions = []
        }
        
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                throw NSError(domain: "Debug", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user or card ID"])
            }
            
            print("🔍 [StrigaDebug] Loading transactions for user: \(userId)")
            
            // Get card's wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            let walletId = cardResponse.parentWalletId
            print("💳 [StrigaDebug] Wallet ID: \(walletId)")
            
            // Get wallet details
            let walletResponse = try await striga.getWallet(walletId, userId: userId)
            
            var allTransactions: [StrigaTransaction] = []
            
            // Date range - last 90 days
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
            let fromTimestamp = Int64(startDate.timeIntervalSince1970 * 1000)
            let toTimestamp = Int64(endDate.timeIntervalSince1970 * 1000)
            
            // Only check EUR account for now (where the transactions are)
            let accounts: [(String, CreateWalletResponse.Account?)] = [
                ("EUR", walletResponse.accounts.eur)
            ]
            
            for (currency, account) in accounts {
                guard let account = account else {
                    print("⚠️ WARNING [StrigaDebug] Skipping \(currency) - account not found in wallet")
                    continue
                }
                
                print("\n📊 [StrigaDebug] Fetching \(currency) transactions...")
                print("   Account ID: \(account.accountId)")
                print("   Date range: \(startDate) to \(endDate)")
                
                // Add small delay between requests to avoid cancellation
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
                // Use account statements endpoint directly
                do {
                    let statement = try await striga.accountStatements(.init(
                        userId: userId,
                        walletId: walletId,
                        accountId: account.accountId,
                        startDate: fromTimestamp,
                        endDate: toTimestamp,
                        page: 1
                    ))
                    
                    print("✅ [StrigaDebug] Found \(statement.transactions.count) \(currency) transactions")
                    
                    for strigaTx in statement.transactions {
                        let dateFormatter = ISO8601DateFormatter()
                        let date = dateFormatter.date(from: strigaTx.timestamp) ?? Date()
                        
                        let displayFormatter = DateFormatter()
                        displayFormatter.dateFormat = "dd MMM yyyy HH:mm"
                        
                        // Get the actual amount (using computed property that handles debit/credit)
                        let amountRaw = strigaTx.amount
                        
                        // Format amount for display (convert cents to euros for EUR)
                        let displayAmount: String
                        if currency == "EUR" {
                            let amountDouble = Double(amountRaw) ?? 0
                            let euroAmount = amountDouble / 100.0
                            displayAmount = String(format: "%.2f", euroAmount)
                        } else {
                            displayAmount = amountRaw
                        }
                        
                        let tx = StrigaTransaction(
                            id: strigaTx.id,
                            type: strigaTx.txType,
                            amount: displayAmount,
                            currency: strigaTx.currency,
                            date: displayFormatter.string(from: date),
                            timestamp: date,
                            accountType: currency,
                            raw: "\(strigaTx.txType) - \(strigaTx.memo ?? "no memo")"
                        )
                        allTransactions.append(tx)
                    }
                } catch {
                    print("❌ ERROR [StrigaDebug] Failed fetching \(currency) transactions:")
                    print("   Account ID: \(account.accountId)")
                    print("   Error type: \(type(of: error))")
                    print("   Error description: \(error.localizedDescription)")
                    
                    if let urlError = error as? URLError {
                        print("   URL Error code: \(urlError.code.rawValue)")
                        if urlError.code == .cancelled {
                            print("   ⚠️ WARNING Request was cancelled - likely due to view dismissal or navigation")
                        }
                    } else if let decodingError = error as? DecodingError {
                        print("   🔍 ERROR Decoding error details: \(decodingError)")
                    }
                }
            }
            
            // Sort by date
            allTransactions.sort { $0.timestamp > $1.timestamp }
            
            print("📊 [StrigaDebug] Total Striga transactions: \(allTransactions.count)")
            
            await MainActor.run {
                self.strigaTransactions = allTransactions
                self.isLoading = false
            }
            
        } catch {
            print("❌ ERROR [StrigaDebug] Failed to load transactions: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}