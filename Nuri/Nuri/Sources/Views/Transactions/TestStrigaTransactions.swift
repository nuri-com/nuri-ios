import SwiftUI
import StrigaAPI

// Simple test view to debug Striga transaction fetching
struct TestStrigaTransactions: View {
    @State private var transactions: String = "Loading..."
    private let striga = StrigaService.shared
    
    var body: some View {
        VStack {
            Text("Striga Transaction Test")
                .font(.title)
            
            ScrollView {
                Text(transactions)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            
            Button("Fetch Transactions") {
                Task {
                    await fetchTransactions()
                }
            }
            .padding()
        }
        .task {
            await fetchTransactions()
        }
    }
    
    private func fetchTransactions() async {
        do {
            guard let userId = StrigaSession.shared.userId ?? UserSettings().strigaUserId,
                  let cardId = StrigaSession.shared.cardId ?? UserSettings().strigaCardId else {
                await MainActor.run {
                    transactions = "Missing user or card ID"
                }
                return
            }
            
            var result = "Fetching transactions...\n"
            result += "User ID: \(userId)\n"
            result += "Card ID: \(cardId)\n\n"
            
            // Get card's wallet
            let cardResponse = try await striga.getCard(.init(
                userId: userId,
                cardId: cardId,
                authToken: nil
            ))
            
            let walletId = cardResponse.parentWalletId
            result += "Wallet ID: \(walletId)\n\n"
            
            // Get wallet details
            let walletResponse = try await striga.getWallet(walletId, userId: userId)
            
            // Try to get EUR transactions only
            if let eurAccount = walletResponse.accounts.eur {
                result += "EUR Account ID: \(eurAccount.accountId)\n"
                result += "EUR Balance: \(eurAccount.availableBalance.amount)\n\n"
                
                // Simple date range - last 30 days
                let endDate = Date()
                let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
                
                // Convert to Unix timestamps in milliseconds
                let startTimestamp = Int64(startDate.timeIntervalSince1970 * 1000)
                let endTimestamp = Int64(endDate.timeIntervalSince1970 * 1000)
                
                result += "Using Unix timestamps (milliseconds):\n"
                result += "Start: \(startTimestamp) (\(startDate))\n"
                result += "End: \(endTimestamp) (\(endDate))\n\n"
                
                do {
                    // Try with Unix timestamps
                    let statement = try await striga.accountStatements(.init(
                        userId: userId,
                        walletId: walletId,
                        accountId: eurAccount.accountId,
                        startDate: startTimestamp,
                        endDate: endTimestamp,
                        page: 1
                    ))
                    
                    result += "SUCCESS! Found \(statement.transactions.count) transactions\n\n"
                    
                    for tx in statement.transactions.prefix(5) {
                        result += "Transaction:\n"
                        result += "  ID: \(tx.id)\n"
                        result += "  Type: \(tx.transactionType)\n"
                        result += "  Amount: \(tx.amount) \(tx.currency)\n"
                        result += "  Date: \(tx.timestamp)\n"
                        result += "  Status: \(tx.status)\n\n"
                    }
                } catch {
                    result += "Error with Unix timestamps: \(error)\n\n"
                }
            } else {
                result += "No EUR account found\n"
            }
            
            await MainActor.run {
                transactions = result
            }
            
        } catch {
            await MainActor.run {
                transactions = "Error: \(error)"
            }
        }
    }
}