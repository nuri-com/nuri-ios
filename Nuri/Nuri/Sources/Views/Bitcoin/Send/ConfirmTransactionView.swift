import SwiftUI
import BitcoinDevKit

struct ConfirmTransactionView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    // Values provided by previous screen
    let btcAmount: Double
    let eurAmount: Double
    let recipientAddress: String
    
    // Transaction state
    @State private var transactionInfo: TransactionManager.TransactionInfo?
    @State private var isLoadingFee = true
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var transactionId = ""
    
    // Services
    private let transactionManager = TransactionManager.shared

    var body: some View {
        Screen {
            NuriHeader<AnyView, AnyView>.backAndClose(
                title: "Confirm Transaction",
                onBack: { dismiss() },
                onClose: { navigation.isSendViewPresented = false }
            )
        } content: {
            if isLoadingFee {
                VStack {
                    Spacer()
                    ProgressView("Calculating transaction fee...")
                        .scaleEffect(1.2)
                    Spacer()
                }
                .padding(32)
            } else {
                VStack(spacing: 16) {
                    // Amount
                    HStack(spacing: 8) {
                        Text("₿")
                            .font(.system(size: 40, weight: .semibold))
                        Text(String(format: "%0.8f", btcAmount).trimTrailingZeros())
                            .font(.system(size: 40, weight: .semibold))
                    }
                    Text(String(format: "~ %.2f EUR", eurAmount))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)

                    // Details card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipient")
                            .font(.custom("Inter", size: 16).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        recipientView()
                        Divider()
                        HStack {
                            Text("Send")
                                .font(.custom("Inter", size: 16))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                            Spacer()
                            Text(String(format: "%0.8f BTC", btcAmount))
                                .font(.custom("Inter", size: 16).weight(.medium))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                        }
                        HStack {
                            Text("From Bitcoin Wallet")
                                .font(.custom("Inter", size: 16))
                                .foregroundColor(Color("TextSecondary"))
                            Spacer()
                            Text(String(format: "%.2f EUR", eurAmount))
                                .font(.custom("Inter", size: 16))
                                .foregroundColor(Color("TextSecondary"))
                        }
                        Divider()
                        HStack {
                            Text("Network Fee")
                                .font(.custom("Inter", size: 16))
                                .foregroundColor(Color("PrimaryNuriBlack"))
                            Spacer()
                            if let txInfo = transactionInfo {
                                Text(String(format: "%0.8f BTC", txInfo.feeBTC))
                                    .font(.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            } else {
                                Text("Calculating...")
                                    .font(.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            }
                        }
                        HStack {
                            Spacer()
                            if let txInfo = transactionInfo {
                                Text("Fee rate: \(txInfo.feeRate) sat/vB")
                                    .font(.custom("Inter", size: 16))
                                    .foregroundColor(Color("TextSecondary"))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.vertical, 16)

                    Spacer()

                    Button(action: sendTransaction) {
                        if isSending {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                Text("Sending...")
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            NuriButton(icon: "bitcoin-circle", title: "Send Bitcoin", style: .primary)
                        }
                    }
                    .disabled(isSending || transactionInfo == nil)
                }
                .padding(32)
            }
        }
        .task {
            await loadTransactionInfo()
        }
        .alert("Transaction Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showSuccess) {
            SuccessView(
                illustration: "bitcoin-sent", 
                title: "Bitcoin sent!", 
                subtitle: "Transaction ID: \(transactionId)",
                onDone: {
                    navigation.isSendViewPresented = false
                }
            )
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func recipientView() -> some View {
        let segments = segmentedRecipient()
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { idx in
                let seg = segments[idx]
                Text(seg)
                    .font(.custom("Inter", size: 16).weight(idx % 2 == 0 ? .semibold : .regular))
                    .foregroundColor(idx % 2 == 0 ? Color("PrimaryNuriBlack") : Color("TextSecondary"))
            }
        }
        .textSelection(.enabled)
    }

    private func segmentedRecipient() -> [String] {
        stride(from: 0, to: recipientAddress.count, by: 5).map { start in
            let end = min(start + 5, recipientAddress.count)
            let startIdx = recipientAddress.index(recipientAddress.startIndex, offsetBy: start)
            let endIdx = recipientAddress.index(recipientAddress.startIndex, offsetBy: end)
            return String(recipientAddress[startIdx..<endIdx])
        }
    }

    private var formattedBtc: String {
        String(format: "%0.8f", btcAmount).trimTrailingZeros()
    }
    
    // MARK: - Transaction Methods
    
    private func loadTransactionInfo() async {
        do {
            let amountSats = UInt64(btcAmount * 100_000_000) // Convert BTC to satoshis
            
            let txInfo = try await transactionManager.buildTransactionInfo(
                recipientAddress: recipientAddress,
                amountSats: amountSats
            )
            
            await MainActor.run {
                self.transactionInfo = txInfo
                self.isLoadingFee = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoadingFee = false
            }
        }
    }
    
    private func sendTransaction() {
        guard let txInfo = transactionInfo else { return }
        
        isSending = true
        
        Task {
            do {
                let txId = try await transactionManager.sendTransaction(
                    recipientAddress: recipientAddress,
                    amountSats: txInfo.amountSats,
                    feeRate: txInfo.feeRate
                )
                
                await MainActor.run {
                    self.transactionId = txId
                    self.isSending = false
                    self.showSuccess = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSending = false
                    self.showError = true
                }
            }
        }
    }
}

private extension String {
    /// Removes trailing zeros from a decimal string ("0.10000000" -> "0.1").
    func trimTrailingZeros() -> String {
        var s = self
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return s
    }
}
