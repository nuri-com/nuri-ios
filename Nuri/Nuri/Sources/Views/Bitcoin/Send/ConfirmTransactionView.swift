import SwiftUI
import BitcoinDevKit

struct ConfirmTransactionView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss

    // Values provided by previous screen
    let btcAmount: Double
    let eurAmount: Double
    let recipientAddress: String
    
    init(btcAmount: Double, eurAmount: Double, recipientAddress: String) {
        print("🏗️ [ConfirmTransactionView] ========== INIT START ==========")
        print("🏗️ [ConfirmTransactionView] Initializing with:")
        print("   ₿ btcAmount: \(btcAmount)")
        print("   💶 eurAmount: \(eurAmount)")
        print("   📍 recipientAddress: \(recipientAddress)")
        print("   💰 Calculated sats: \(UInt64(btcAmount * 100_000_000))")
        print("   🔍 btcAmount == 0? \(btcAmount == 0)")
        print("   🔍 btcAmount type: \(type(of: btcAmount))")
        print("   🔍 Raw btcAmount bytes: \(String(format: "%.20f", btcAmount))")
        print("🏗️ [ConfirmTransactionView] ========== INIT END ==========")
        
        self.btcAmount = btcAmount
        self.eurAmount = eurAmount
        self.recipientAddress = recipientAddress
    }
    
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
    @StateObject private var walletState = WalletStateManager.shared
    
    // Computed properties
    private var isInsufficientFunds: Bool {
        guard let txInfo = transactionInfo else { return false }
        return txInfo.totalSats > walletState.availableBalance
    }

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
                    HStack(spacing: 4) {
                        Text("₿")
                            .font(.system(size: 40, weight: .semibold))
                        Text(String(UInt64(btcAmount * 100_000_000)))
                            .font(.system(size: 40, weight: .semibold))
                    }
                    Text(String(format: "~ %.2f EUR", eurAmount))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)

                    // Balance display
                    if walletState.availableBalance > 0 {
                        HStack(spacing: 4) {
                            Text("Balance:")
                            Text("₿")
                            Text("\(walletState.availableBalance)")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#6D6D86"))
                        .padding(.top, 8)
                    }

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
                            Text("₿ \(String(UInt64(btcAmount * 100_000_000)))")
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
                                Text("₿ \(String(txInfo.feeSats))")
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

                    // Total Amount Display (above button)
                    if let txInfo = transactionInfo {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Total Amount:")
                                    .font(.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                                Spacer()
                                Text("₿ \(txInfo.totalSats)")
                                    .font(.custom("Inter", size: 18).weight(.semibold))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            }
                            HStack {
                                Text("(Amount + Network Fee)")
                                    .font(.custom("Inter", size: 14))
                                    .foregroundColor(Color(hex: "#6D6D86"))
                                Spacer()
                            }
                            
                            // Insufficient funds warning
                            if txInfo.totalSats > walletState.availableBalance {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                    Text("Insufficient funds")
                                        .font(.custom("Inter", size: 14).weight(.medium))
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(hex: "#F8F9FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 16)
                    }

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
                            NuriButton(
                                icon: "bitcoin-circle", 
                                title: isInsufficientFunds ? "Insufficient Funds" : "Send Bitcoin", 
                                style: isInsufficientFunds ? .secondary : .primary
                            )
                        }
                    }
                    .disabled(isSending || transactionInfo == nil || isInsufficientFunds)
                }
                .padding(32)
            }
        }
        .task {
            print("🔄 [ConfirmTransactionView] Task started - about to load transaction info")
            print("🔄 [ConfirmTransactionView] Current btcAmount in task: \(btcAmount)")
            
            // Wait for valid navigation data - retry for up to 2 seconds
            var attempts = 0
            let maxAttempts = 20 // 20 attempts * 100ms = 2 seconds max
            
            while (btcAmount <= 0 || recipientAddress.isEmpty) && attempts < maxAttempts {
                print("🔄 [ConfirmTransactionView] Waiting for valid data... attempt \(attempts + 1)")
                print("🔄 [ConfirmTransactionView]   btcAmount: \(btcAmount), recipientAddress: '\(recipientAddress)'")
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
            
            // Final validation
            guard btcAmount > 0, !recipientAddress.isEmpty else {
                print("❌ [ConfirmTransactionView] Invalid data after waiting - btcAmount: \(btcAmount), recipientAddress: '\(recipientAddress)'")
                await MainActor.run {
                    self.errorMessage = "Invalid transaction data. Please try again."
                    self.showError = true
                    self.isLoadingFee = false
                }
                return
            }
            
            print("✅ [ConfirmTransactionView] Valid data received - proceeding with transaction info loading")
            await loadBalanceAndTransactionInfo()
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
        "₿ \(String(UInt64(btcAmount * 100_000_000)))"
    }
    
    // MARK: - Transaction Methods
    
    private func loadBalanceAndTransactionInfo() async {
        // Get cached balance and fee rates (instant)
        let _ = await walletState.getBalance(forceRefresh: false)
        let _ = await walletState.getFeeRates(forceRefresh: false)
        
        // Then create transaction info using cached fee rates
        await loadTransactionInfo()
    }
    
    private func loadTransactionInfo() async {
        print("🔧 [ConfirmTransactionView] ========== LOAD TRANSACTION INFO START ==========")
        print("🔧 [ConfirmTransactionView] Current btcAmount: \(btcAmount)")
        print("🔧 [ConfirmTransactionView] Current eurAmount: \(eurAmount)")
        print("🔧 [ConfirmTransactionView] Current recipientAddress: \(recipientAddress)")
        
        do {
            let amountSats = UInt64(btcAmount * 100_000_000)
            print("🔧 [ConfirmTransactionView] Calculated amountSats: \(amountSats)")
            print("🔧 [ConfirmTransactionView] Calculation: \(btcAmount) * 100_000_000 = \(btcAmount * 100_000_000)")
            print("🔧 [ConfirmTransactionView] UInt64 conversion: UInt64(\(btcAmount * 100_000_000)) = \(amountSats)")
            
            if amountSats == 0 {
                print("❌ [ConfirmTransactionView] 🚨 CRITICAL: amountSats is 0!")
                print("❌ [ConfirmTransactionView] btcAmount: \(btcAmount)")
                print("❌ [ConfirmTransactionView] btcAmount * 100_000_000: \(btcAmount * 100_000_000)")
                print("❌ [ConfirmTransactionView] This will cause the 'invalid amount: 0 sats' error!")
            }
            
            // Use cached fee rate instead of recalculating
            let feeRate = walletState.feeRates.defaultFee
            print("⚡ [ConfirmTransactionView] Using cached fee rate: \(feeRate) sat/vB")
            print("⚡ [ConfirmTransactionView] Fee rates object: \(walletState.feeRates)")
            
            let estimatedFee = walletState.feeRates.estimatedFee(amountSats: amountSats, feeRate: feeRate)
            let totalSats = amountSats + estimatedFee
            
            print("💰 [ConfirmTransactionView] Fee calculation:")
            print("   💰 amountSats: \(amountSats)")
            print("   ⚡ estimatedFee: \(estimatedFee)")
            print("   📊 totalSats: \(totalSats)")
            
            // Create transaction info directly instead of calculating via TransactionManager
            let txInfo = TransactionManager.TransactionInfo(
                recipientAddress: recipientAddress,
                amountSats: amountSats,
                feeSats: estimatedFee,
                totalSats: totalSats,
                feeRate: feeRate
            )
            
            print("✅ [ConfirmTransactionView] Transaction info created using cached fee rates:")
            print("   📍 recipientAddress: \(txInfo.recipientAddress)")
            print("   💰 amountSats: \(txInfo.amountSats)")
            print("   ⚡ feeSats: \(txInfo.feeSats)")
            print("   📊 totalSats: \(txInfo.totalSats)")
            print("   ⚡ feeRate: \(txInfo.feeRate)")
            
            print("🔧 [ConfirmTransactionView] About to set transactionInfo on MainActor...")
            await MainActor.run {
                print("🔧 [ConfirmTransactionView] Setting transactionInfo and isLoadingFee on MainActor")
                self.transactionInfo = txInfo
                self.isLoadingFee = false
                print("🔧 [ConfirmTransactionView] transactionInfo set: \(String(describing: self.transactionInfo))")
                print("🔧 [ConfirmTransactionView] isLoadingFee set to: \(self.isLoadingFee)")
            }
            print("🔧 [ConfirmTransactionView] ========== LOAD TRANSACTION INFO SUCCESS ==========")
            
        } catch {
            print("❌ [ConfirmTransactionView] Transaction info loading failed: \(error.localizedDescription)")
            if let txError = error as? TransactionManager.TransactionError {
                print("   🔍 Error type: \(txError)")
            }
            
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoadingFee = false
            }
        }
    }
    
    private func sendTransaction() {
        print("🚀 [ConfirmTransactionView] ========== SEND TRANSACTION START ==========")
        print("🚀 [ConfirmTransactionView] sendTransaction() called")
        print("🚀 [ConfirmTransactionView] transactionInfo: \(String(describing: transactionInfo))")
        
        guard let txInfo = transactionInfo else { 
            print("❌ [ConfirmTransactionView] 🚨 CRITICAL: transactionInfo is nil!")
            print("❌ [ConfirmTransactionView] Cannot proceed with transaction")
            return 
        }
        
        print("✅ [ConfirmTransactionView] transactionInfo found:")
        print("   📍 recipientAddress: \(txInfo.recipientAddress)")
        print("   💰 amountSats: \(txInfo.amountSats)")
        print("   ⚡ feeSats: \(txInfo.feeSats)")
        print("   📊 totalSats: \(txInfo.totalSats)")
        print("   ⚡ feeRate: \(txInfo.feeRate)")
        
        if txInfo.amountSats == 0 {
            print("❌ [ConfirmTransactionView] 🚨 CRITICAL: txInfo.amountSats is 0!")
            print("❌ [ConfirmTransactionView] This will definitely cause 'invalid amount: 0 sats' error")
            print("❌ [ConfirmTransactionView] Original btcAmount: \(btcAmount)")
            print("❌ [ConfirmTransactionView] Original eurAmount: \(eurAmount)")
        }
        
        print("🚀 [ConfirmTransactionView] Setting isSending = true")
        isSending = true
        
        print("🚀 [ConfirmTransactionView] Starting async Task for transaction...")
        Task {
            do {
                print("🚀 [ConfirmTransactionView] About to call TransactionManager.sendTransaction with:")
                print("   📍 recipientAddress: \(recipientAddress)")
                print("   💰 amountSats: \(txInfo.amountSats)")
                print("   ⚡ feeRate: \(txInfo.feeRate)")
                print("🚀 [ConfirmTransactionView] Calling transactionManager.sendTransaction()...")
                
                let txId = try await transactionManager.sendTransaction(
                    recipientAddress: recipientAddress,
                    amountSats: txInfo.amountSats,
                    feeRate: txInfo.feeRate
                )
                
                print("✅ [ConfirmTransactionView] TransactionManager.sendTransaction() completed successfully!")
                print("   🆔 Transaction ID: \(txId)")
                
                // Immediately update wallet state with pending transaction
                print("✅ [ConfirmTransactionView] Transaction sent successfully, updating state...")
                walletState.addPendingTransaction(
                    txId: txId,
                    amount: txInfo.amountSats,
                    recipientAddress: recipientAddress,
                    fee: txInfo.feeSats
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
