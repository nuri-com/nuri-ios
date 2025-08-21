import SwiftUI
import BitcoinDevKit
import AuthenticationServices

struct ConfirmTransactionView: View {

    @EnvironmentObject var navigation: BitcoinViewNavigation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var walletState = WalletStateManager.shared

    // Transaction data from WalletStateManager
    private var transactionData: WalletStateManager.PendingTransactionData? {
        walletState.pendingTransactionData
    }
    
    init() {
        print("🏗️ [ConfirmTransactionView] ========== INIT START ==========")
        print("🏗️ [ConfirmTransactionView] Initializing without parameters - will read from WalletStateManager")
        print("🏗️ [ConfirmTransactionView] ========== INIT END ==========")
    }
    
    // Transaction state
    @State private var transactionInfo: TransactionManager.TransactionInfo?
    @State private var isLoadingFee = true
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var transactionId = ""
    
    // Hardware security key verification
    @State private var isVerifyingSecurityKey = false
    @State private var showSecurityKeyAlert = false
    @State private var securityKeyVerified = false
    
    // Services
    private let transactionManager = TransactionManager.shared
    
    // Computed properties
    private var isInsufficientFunds: Bool {
        guard let txInfo = transactionInfo else { return false }
        return txInfo.totalSats > walletState.availableBalance
    }
    
    private var shouldDisableButton: Bool {
        return isSending || transactionInfo == nil || transactionData == nil || isInsufficientFunds
    }
    
    private var buttonTitle: String {
        if transactionData == nil {
            return "Loading..."
        } else if isInsufficientFunds {
            return "Insufficient Funds"
        } else {
            let hasUsername = UserDefaults.standard.string(forKey: "passkeyUsername") != nil
            let hasCredentialId = UserDefaults.standard.string(forKey: "passkeyCredentialId") != nil
            let hasRegisteredHardwareKey = hasUsername && hasCredentialId
            
            if hasRegisteredHardwareKey && !securityKeyVerified {
                return "Confirm Transaction"
            } else {
                return "Send Bitcoin"
            }
        }
    }
    
    private var buttonStyle: NuriButton.Style {
        if transactionData == nil || isInsufficientFunds {
            return .secondary
        } else {
            return .primary
        }
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
                    // Amount display - EUR on top, BTC below
                    if let txData = transactionData, let txInfo = transactionInfo {
                        // Calculate EUR exchange rate from the original transaction data
                        let btcAmount = Double(txData.amountSats) / 100_000_000
                        let eurRate = txData.eurAmount / btcAmount
                        
                        // Calculate fee in EUR using the same rate
                        let feeInBTC = Double(txInfo.feeSats) / 100_000_000
                        let feeInEUR = feeInBTC * eurRate
                        let totalEUR = txData.eurAmount + feeInEUR
                        
                        VStack(spacing: 4) {
                            // EUR amount
                            HStack(spacing: 4) {
                                Text("€")
                                    .font(.system(size: 40, weight: .semibold))
                                Text(String(format: "%.2f", totalEUR))
                                    .font(.system(size: 40, weight: .semibold))
                            }
                            
                            // Bitcoin amount
                            HStack(spacing: 4) {
                                Text("₿")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                                Text(String(txInfo.totalSats))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            }
                        }
                    } else {
                        Text("Loading transaction data...")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }


                    // Details card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipient")
                            .font(.custom("Inter", size: 16).weight(.medium))
                            .foregroundColor(Color("PrimaryNuriBlack"))
                        recipientView()
                        Divider()
                        if let txData = transactionData {
                            HStack {
                                Text("Send")
                                    .font(.custom("Inter", size: 16))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                                Spacer()
                                Text("₿ \(String(txData.amountSats))")
                                    .font(.custom("Inter", size: 16).weight(.medium))
                                    .foregroundColor(Color("PrimaryNuriBlack"))
                            }
                            HStack {
                                Text("From Bitcoin Wallet")
                                    .font(.custom("Inter", size: 16))
                                    .foregroundColor(Color("TextSecondary"))
                                Spacer()
                                Text(String(format: "%.2f EUR", txData.eurAmount))
                                    .font(.custom("Inter", size: 16))
                                    .foregroundColor(Color("TextSecondary"))
                            }
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

                    // Fee calculation display (above button)
                    if let txData = transactionData, let txInfo = transactionInfo {
                        Text("₿ \(String(txData.amountSats)) Amount + ₿ \(String(txInfo.feeSats)) Fee = ₿ \(String(txInfo.totalSats))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#6D6D86"))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
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
                                title: buttonTitle, 
                                style: buttonStyle
                            )
                        }
                    }
                    .disabled(shouldDisableButton)
                }
                .padding(32)
            }
        }
        .task {
            print("🔄 [ConfirmTransactionView] Task started - loading transaction info from WalletStateManager")
            await loadBalanceAndTransactionInfo()
        }
        .onDisappear {
            // Clear transaction data when leaving the screen
            walletState.clearPendingTransactionData()
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
        .alert("Security Key Required", isPresented: $showSecurityKeyAlert) {
            Button("Verify with Security Key", role: .none) {
                Task {
                    await verifySecurityKey()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please connect and verify your hardware security key to authorize this transaction.")
        }
        .overlay {
            if isVerifyingSecurityKey {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Verifying Security Key...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Please touch your security key when prompted")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func recipientView() -> some View {
        if let address = transactionData?.recipientAddress {
            Text(address)
                .font(.custom("Inter", size: 16))
                .foregroundColor(Color("PrimaryNuriBlack"))
                .textSelection(.enabled)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        } else {
            Text("Loading...")
                .font(.custom("Inter", size: 16))
                .foregroundColor(Color("TextSecondary"))
        }
    }

    private var formattedBtc: String {
        guard let txData = transactionData else { return "₿ 0" }
        return "₿ \(String(txData.amountSats))"
    }
    
    // MARK: - Transaction Methods
    
    private func loadBalanceAndTransactionInfo() async {
        print("🔧 [ConfirmTransactionView] Loading transaction info INSTANTLY using cached data")
        
        // No need to await - we use cached balance and fee rates that are already loaded
        // The wallet state manager already has this data cached from the main screen
        await loadTransactionInfo()
    }
    
    private func loadTransactionInfo() async {
        print("🔧 [ConfirmTransactionView] ========== INSTANT TRANSACTION INFO ==========")
        print("🔧 [ConfirmTransactionView] Using cached fee rates for instant calculation")
        
        guard let txData = transactionData else {
            print("❌ [ConfirmTransactionView] No transaction data found in WalletStateManager")
            await MainActor.run {
                self.errorMessage = "No transaction data found. Please try again."
                self.showError = true
                self.isLoadingFee = false
            }
            return
        }
        
        let amountSats = txData.amountSats
        print("🔧 [ConfirmTransactionView] Using transaction data:")
        print("   💰 Amount: \(amountSats) sats")
        print("   💶 EUR Amount: \(txData.eurAmount)")
        print("   📍 Recipient: \(txData.recipientAddress)")
        
        if amountSats == 0 {
            print("❌ [ConfirmTransactionView] Invalid amount: \(amountSats) sats")
            await MainActor.run {
                self.errorMessage = "Invalid transaction amount"
                self.showError = true
                self.isLoadingFee = false
            }
            return
        }
        
        // Use cached fee rate - no network calls needed!
        let feeRate = walletState.feeRates.defaultFee
        let estimatedFee = walletState.feeRates.estimatedFee(amountSats: amountSats, feeRate: feeRate)
        let totalSats = amountSats + estimatedFee
        
        print("⚡ [ConfirmTransactionView] INSTANT calculation:")
        print("   💰 Amount: \(amountSats) sats")
        print("   ⚡ Fee: \(estimatedFee) sats (at \(feeRate) sat/vB)")
        print("   📊 Total: \(totalSats) sats")
        
        // Create transaction info instantly
        let txInfo = TransactionManager.TransactionInfo(
            recipientAddress: txData.recipientAddress,
            amountSats: amountSats,
            feeSats: estimatedFee,
            totalSats: totalSats,
            feeRate: feeRate
        )
        
        // Set immediately on main thread
        await MainActor.run {
            self.transactionInfo = txInfo
            self.isLoadingFee = false
            print("✅ [ConfirmTransactionView] Transaction info set INSTANTLY!")
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
        
        // Check if user has a registered hardware security key (single device)
        // We need to check if there's a username AND a credential ID stored
        let hasUsername = UserDefaults.standard.string(forKey: "passkeyUsername") != nil
        let hasCredentialId = UserDefaults.standard.string(forKey: "passkeyCredentialId") != nil
        let hasRegisteredHardwareKey = hasUsername && hasCredentialId
        
        if hasRegisteredHardwareKey && !securityKeyVerified {
            print("🔐 [ConfirmTransactionView] Hardware security key required for transaction")
            print("   Username: \(UserDefaults.standard.string(forKey: "passkeyUsername") ?? "none")")
            print("   Has Key: \(hasCredentialId)")
            showSecurityKeyAlert = true
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
            if let txData = transactionData {
                print("❌ [ConfirmTransactionView] Original transaction data:")
                print("   ₿ btcAmount: \(txData.btcAmount)")
                print("   💶 eurAmount: \(txData.eurAmount)")
                print("   💰 amountSats: \(txData.amountSats)")
            }
        }
        
        print("🚀 [ConfirmTransactionView] Setting isSending = true")
        isSending = true
        
        print("🚀 [ConfirmTransactionView] Starting async Task for transaction...")
        Task {
            do {
                print("🚀 [ConfirmTransactionView] About to call TransactionManager.sendTransaction with:")
                print("   📍 recipientAddress: \(txInfo.recipientAddress)")
                print("   💰 amountSats: \(txInfo.amountSats)")
                print("   ⚡ feeRate: \(txInfo.feeRate)")
                print("🚀 [ConfirmTransactionView] Calling transactionManager.sendTransactionDirect()...")
                
                // Use direct transaction sending to bypass expensive fee recalculation
                let txId = try await transactionManager.sendTransactionDirect(
                    recipientAddress: txInfo.recipientAddress,
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
                    recipientAddress: txInfo.recipientAddress,
                    fee: txInfo.feeSats
                )
                
                await MainActor.run {
                    self.transactionId = txId
                    self.isSending = false
                    self.securityKeyVerified = false // Reset for next transaction
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
    
    // MARK: - Security Key Verification
    
    @MainActor
    private func verifySecurityKey() async {
        print("🔐 [ConfirmTransactionView] Starting security key verification")
        
        isVerifyingSecurityKey = true
        defer { isVerifyingSecurityKey = false }
        
        do {
            // Get the window for presentation
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow }) else {
                print("❌ [ConfirmTransactionView] Failed to get presentation window")
                errorMessage = "Failed to get presentation window"
                showError = true
                return
            }
            
            // Get the stored username - REQUIRED for hardware key verification
            guard let username = UserDefaults.standard.string(forKey: "passkeyUsername") else {
                print("❌ [ConfirmTransactionView] No passkey username found")
                errorMessage = "No registered user found. Please register a security key first."
                showError = true
                return
            }
            
            print("🔐 [ConfirmTransactionView] Authenticating with hardware security key ONLY for user: \(username)")
            
            // Use the new method that ONLY prompts for hardware security key
            let result = try await PasskeyAuthenticationService.shared.authenticateWithSecurityKeyOnly(
                username: username,
                presentationAnchor: window
            )
            
            if result.verified {
                print("✅ [ConfirmTransactionView] Security key verified successfully")
                securityKeyVerified = true
                
                // Now proceed with the transaction
                sendTransaction()
            } else {
                print("❌ [ConfirmTransactionView] Security key verification failed")
                errorMessage = "Security key verification failed. Please try again."
                showError = true
            }
            
        } catch {
            print("❌ [ConfirmTransactionView] Security key verification error: \(error)")
            
            // Handle specific error cases
            if error.localizedDescription.contains("cancelled") || error.localizedDescription.contains("canceled") {
                // User cancelled - no need to show error
                print("⚠️ [ConfirmTransactionView] User cancelled security key verification")
            } else {
                errorMessage = "Failed to verify security key: \(error.localizedDescription)"
                showError = true
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
