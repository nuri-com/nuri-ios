import Foundation
import BitcoinDevKit

/// Manages Bitcoin transaction creation, signing, and broadcasting
final class TransactionManager {
    static let shared = TransactionManager()
    
    // MARK: - Constants
    private let DEFAULT_FEE_RATE: UInt64 = 1 // 1 sat/vB default
    private let MIN_FEE_RATE: UInt64 = 1
    private let MAX_FEE_RATE: UInt64 = 1000
    
    // MARK: - Dependencies
    private let walletService: BitcoinWalletService
    private let walletState = WalletStateManager.shared
    
    private init(walletService: BitcoinWalletService = .shared) {
        self.walletService = walletService
    }
    
    // MARK: - Error Types
    enum TransactionError: Error, LocalizedError {
        case walletNotAvailable
        case invalidAddress(String)
        case invalidAmount(String)
        case insufficientFunds(available: UInt64, required: UInt64)
        case feeCalculationFailed
        case buildTransactionFailed(Error)
        case signingFailed(Error)
        case broadcastFailed(Error)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .walletNotAvailable:
                return "Bitcoin wallet is not available. Please ensure your wallet is initialized."
            case .invalidAddress(let address):
                return "Invalid Bitcoin address: \(address)"
            case .invalidAmount(let amount):
                return "Invalid amount: \(amount)"
            case .insufficientFunds(let available, let required):
                return "Insufficient funds. Available: \(available) sats, Required: \(required) sats"
            case .feeCalculationFailed:
                return "Failed to calculate transaction fee"
            case .buildTransactionFailed(let error):
                return "Failed to build transaction: \(error.localizedDescription)"
            case .signingFailed(let error):
                return "Failed to sign transaction: \(error.localizedDescription)"
            case .broadcastFailed(let error):
                return "Failed to broadcast transaction: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Transaction Info
    struct TransactionInfo {
        let recipientAddress: String
        let amountSats: UInt64
        let feeSats: UInt64
        let totalSats: UInt64
        let feeRate: UInt64
        
        var amountBTC: Double {
            Double(amountSats) / 100_000_000.0
        }
        
        var feeBTC: Double {
            Double(feeSats) / 100_000_000.0
        }
        
        var totalBTC: Double {
            Double(totalSats) / 100_000_000.0
        }
    }
    
    // MARK: - Public API
    
    /// Validates a Bitcoin address
    func validateAddress(_ address: String) -> Bool {
        do {
            // Use the current network from wallet service
            let network: Network = .bitcoin // mainnet
            let _ = try Address(address: address, network: network)
            return true
        } catch {
            print("❌ [TransactionManager] Invalid address validation: \(error)")
            return false
        }
    }
    
    /// Validates transaction amount in satoshis
    func validateAmount(_ amountSats: UInt64) -> Bool {
        // Minimum amount is 546 satoshis (dust limit)
        let dustLimit: UInt64 = 546
        let isValid = amountSats >= dustLimit
        print("✅ [TransactionManager] Amount validation:")
        print("   💰 Amount: \(amountSats) sats")
        print("   🚫 Dust limit: \(dustLimit) sats")
        print("   ✅ Is valid: \(isValid)")
        return isValid
    }
    
    /// Calculates transaction fee for given amount and fee rate
    func calculateFee(amountSats: UInt64, feeRate: UInt64 = 0, recipientAddress: String) async throws -> UInt64 {
        print("🧮 [TransactionManager] ========== FEE CALCULATION START ==========")
        print("🧮 [TransactionManager] Calculating fee for:")
        print("   💰 amountSats: \(amountSats)")
        print("   ⚡ feeRate: \(feeRate)")
        print("   📍 recipientAddress: \(recipientAddress)")
        
        let actualFeeRate = feeRate > 0 ? feeRate : DEFAULT_FEE_RATE
        print("   ⚡ actualFeeRate: \(actualFeeRate) sat/vB (using default: \(feeRate == 0))")
        
        print("🔍 [TransactionManager] Getting wallet...")
        guard let wallet = await getWallet() else {
            print("❌ [TransactionManager] Wallet not available!")
            throw TransactionError.walletNotAvailable
        }
        print("✅ [TransactionManager] Wallet obtained successfully")
        
        // Get current balance from cached state
        print("🔍 [TransactionManager] Getting balance from state manager...")
        let balance = await walletState.getBalance(forceRefresh: false)
        
        print("💰 [TransactionManager] Balance details:")
        print("   ✅ Confirmed: \(balance.confirmed) sats")
        print("   ⏳ Pending: \(balance.pending) sats")
        print("   📊 Total: \(balance.total) sats")
        
        // Check if we have at least the base amount (we'll check amount + fee later)
        if balance.confirmed < amountSats {
            print("❌ [TransactionManager] Insufficient balance for amount alone: need \(amountSats) sats, have \(balance.confirmed) sats")
            throw TransactionError.insufficientFunds(
                available: balance.confirmed,
                required: amountSats
            )
        }
        
        do {
            // Create actual transaction to estimate fee (using real recipient address)
            let script = try Address(address: recipientAddress, network: .bitcoin).scriptPubkey()
            
            let txBuilder = try TxBuilder()
                .addRecipient(
                    script: script,
                    amount: Amount.fromSat(satoshi: amountSats)
                )
                .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: actualFeeRate))
                .finish(wallet: wallet)
            
            // Extract transaction to calculate actual fee
            let transaction = try txBuilder.extractTx()
            
            // Get the actual fee from the transaction
            let sentReceived = wallet.sentAndReceived(tx: transaction)
            let totalSent = sentReceived.sent.toSat()
            let fee = totalSent - amountSats
            
            print("✅ [TransactionManager] Fee calculation successful:")
            print("   📤 Total sent: \(totalSent) sats")
            print("   💰 Amount: \(amountSats) sats")
            print("   💸 Fee: \(fee) sats at \(actualFeeRate) sat/vB")
            
            return fee
            
        } catch {
            print("❌ [TransactionManager] Fee calculation failed: \(error)")
            throw TransactionError.feeCalculationFailed
        }
    }
    
    /// Builds transaction info with fee calculation
    func buildTransactionInfo(
        recipientAddress: String,
        amountSats: UInt64,
        feeRate: UInt64 = 0
    ) async throws -> TransactionInfo {
        
        print("🔧 [TransactionManager] ========== BUILD TRANSACTION INFO START ==========")
        print("🔧 [TransactionManager] Building transaction info with:")
        print("   📍 Recipient: \(recipientAddress)")
        print("   💰 Amount: \(amountSats) sats")
        print("   ⚡ Fee rate: \(feeRate) sat/vB")
        
        // Validate inputs
        print("🔍 [TransactionManager] Validating address...")
        guard validateAddress(recipientAddress) else {
            print("❌ [TransactionManager] Address validation failed: \(recipientAddress)")
            throw TransactionError.invalidAddress(recipientAddress)
        }
        print("✅ [TransactionManager] Address validation passed")
        
        print("🔍 [TransactionManager] Validating amount...")
        guard validateAmount(amountSats) else {
            print("❌ [TransactionManager] Amount validation failed: \(amountSats) sats")
            throw TransactionError.invalidAmount("\(amountSats) sats")
        }
        print("✅ [TransactionManager] Amount validation passed")
        
        let actualFeeRate = feeRate > 0 ? feeRate : DEFAULT_FEE_RATE
        print("   ⚡ Using fee rate: \(actualFeeRate) sat/vB")
        
        // Calculate fee
        print("🔍 [TransactionManager] Calculating transaction fee...")
        let feeSats = try await calculateFee(amountSats: amountSats, feeRate: actualFeeRate, recipientAddress: recipientAddress)
        let totalSats = amountSats + feeSats
        print("✅ [TransactionManager] Fee calculation completed:")
        print("   💰 Amount: \(amountSats) sats")
        print("   💸 Fee: \(feeSats) sats")
        print("   📊 Total needed: \(totalSats) sats")
        
        // Verify we have enough funds including fee (use cached balance for speed)
        print("🔍 [TransactionManager] Final balance check...")
        let balance = await walletState.getBalance(forceRefresh: false)
        
        print("💰 [TransactionManager] Final balance comparison:")
        print("   ✅ Confirmed: \(balance.confirmed) sats")
        print("   ⏳ Pending: \(balance.pending) sats")  
        print("   📊 Total: \(balance.total) sats")
        print("   💸 Required: \(totalSats) sats")
        print("   💡 Using confirmed balance for safety")
        print("   💡 Sufficient funds: \(balance.confirmed >= totalSats)")
        
        if balance.confirmed < totalSats {
            print("❌ [TransactionManager] INSUFFICIENT FUNDS!")
            print("   💰 Need: \(totalSats) sats")
            print("   💰 Have (confirmed): \(balance.confirmed) sats")
            print("   💰 Have (total): \(balance.total) sats")
            print("   💰 Short by: \(totalSats - balance.confirmed) sats")
            throw TransactionError.insufficientFunds(
                available: balance.confirmed,
                required: totalSats
            )
        }
        print("✅ [TransactionManager] Sufficient funds confirmed")
        
        let transactionInfo = TransactionInfo(
            recipientAddress: recipientAddress,
            amountSats: amountSats,
            feeSats: feeSats,
            totalSats: totalSats,
            feeRate: actualFeeRate
        )
        
        print("✅ [TransactionManager] Transaction info built successfully:")
        print("   💰 Amount: \(amountSats) sats (\(transactionInfo.amountBTC) BTC)")
        print("   💸 Fee: \(feeSats) sats (\(transactionInfo.feeBTC) BTC)")
        print("   📊 Total: \(totalSats) sats (\(transactionInfo.totalBTC) BTC)")
        print("   ⚡ Fee rate: \(actualFeeRate) sat/vB")
        print("🔧 [TransactionManager] ========== BUILD TRANSACTION INFO END ==========")
        
        return transactionInfo
    }
    
    /// Sends Bitcoin transaction
    func sendTransaction(
        recipientAddress: String,
        amountSats: UInt64,
        feeRate: UInt64 = 0
    ) async throws -> String {
        
        print("🚀 [TransactionManager] Starting Bitcoin transaction")
        print("   📍 To: \(recipientAddress)")
        print("   💰 Amount: \(amountSats) sats")
        
        // Build transaction info (validates inputs and calculates fee)
        let transactionInfo = try await buildTransactionInfo(
            recipientAddress: recipientAddress,
            amountSats: amountSats,
            feeRate: feeRate
        )
        
        guard let wallet = await getWallet() else {
            throw TransactionError.walletNotAvailable
        }
        
        guard let esploraClient = await getEsploraClient() else {
            throw TransactionError.walletNotAvailable
        }
        
        do {
            // Sync wallet before creating transaction
            print("🔄 [TransactionManager] Syncing wallet before transaction...")
            _ = try await walletService.syncAndGetBalance()
            
            // Build transaction
            print("🔧 [TransactionManager] Building transaction...")
            let psbt = try buildTransaction(
                wallet: wallet,
                recipientAddress: recipientAddress,
                amountSats: amountSats,
                feeRate: transactionInfo.feeRate
            )
            
            // Sign transaction
            print("✍️ [TransactionManager] Signing transaction...")
            let signedPsbt = try signTransaction(wallet: wallet, psbt: psbt)
            
            // Extract final transaction
            print("📤 [TransactionManager] Extracting transaction...")
            let transaction = try signedPsbt.extractTx()
            let txId = transaction.computeTxid()
            
            // Broadcast transaction
            print("📡 [TransactionManager] Broadcasting transaction...")
            try broadcastTransaction(esploraClient: esploraClient, transaction: transaction)
            
            print("✅ [TransactionManager] Transaction sent successfully!")
            print("   🆔 Transaction ID: \(txId)")
            
            return txId
            
        } catch let error as AddressParseError {
            throw TransactionError.invalidAddress(recipientAddress)
        } catch let error as SignerError {
            throw TransactionError.signingFailed(error)
        } catch let error as EsploraError {
            throw TransactionError.broadcastFailed(error)
        } catch {
            throw TransactionError.buildTransactionFailed(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func getWallet() async -> Wallet? {
        return walletService.getWallet()
    }
    
    private func getEsploraClient() async -> EsploraClient? {
        return walletService.getEsploraClient()
    }
    
    private func getCurrentAddress() async throws -> String {
        guard let address = walletService.currentAddress() else {
            throw TransactionError.walletNotAvailable
        }
        return address
    }
    
    private func buildTransaction(
        wallet: Wallet,
        recipientAddress: String,
        amountSats: UInt64,
        feeRate: UInt64
    ) throws -> Psbt {
        
        let script = try Address(address: recipientAddress, network: .bitcoin).scriptPubkey()
        
        let txBuilder = try TxBuilder()
            .addRecipient(
                script: script,
                amount: Amount.fromSat(satoshi: amountSats)
            )
            .feeRate(feeRate: FeeRate.fromSatPerVb(satVb: feeRate))
            .finish(wallet: wallet)
        
        return txBuilder
    }
    
    private func signTransaction(wallet: Wallet, psbt: Psbt) throws -> Psbt {
        let isSigned = try wallet.sign(psbt: psbt)
        
        if !isSigned {
            throw TransactionError.signingFailed(NSError(domain: "TransactionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transaction not fully signed"]))
        }
        
        return psbt
    }
    
    private func broadcastTransaction(esploraClient: EsploraClient, transaction: Transaction) throws {
        try esploraClient.broadcast(transaction: transaction)
    }
}

// MARK: - Extensions